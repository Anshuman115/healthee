"""A claim about the OWNER'S data cites nothing — so nothing was checking it (#129).

## The defect

``validator.py`` checks every interpretive sentence against ``packages/knowledge``. That
is the whole grounding story and it is a story about RESEARCH: a sentence citing
``[alcohol_sleep]`` is checked against the note it names. A sentence about the owner's own
data names no note — there is none to name — so it passes every gate untouched.

Measured 2026-08-03 against a fixture holding **zero** ``manual_entry`` rows of kind
``alcohol``, asked "does alcohol hurt my sleep?":

  * one model answered *"You have 0 logged alcohol events in your recent history."* —
    exactly the behaviour this product promises;
  * one answered from the corpus and made no personal claim — also correct;
  * one opened *"You logged alcohol yesterday afternoon…"* and came back
    ``validated=True``, ``grade_floor=Probable``, because every RESEARCH sentence in it
    was correctly cited. The ship rate scored it a success.

CLAUDE.md's first line is *"'not enough data' always beats an optimistic guess"*.
Fabrication does not fall short of that promise, it inverts it.

## The crux — absence is not assertion

Both of these name a subject the owner has no data for. One is the answer we want:

  * ✅ "You have 0 logged alcohol entries in your history."   — must ship
  * ❌ "You logged alcohol yesterday afternoon."               — must not

A rule keyed on "the answer mentions a subject with no coverage" blocks the honest
sentence and is worse than no rule at all. So the distinction is drawn STRUCTURALLY, by
the same move that fixed citations in #128: the model DECLARES which owner-subjects its
answer states a value for (``coach_answer.CoachAnswer.asserts``). A declared assertion
against nothing is blockable; an absence statement declares nothing and passes untouched.
The model is not asked to classify its own sentences — it is asked what its answer is
about, which is a question it can answer.

## The ground truth

*Does this owner have any data for this subject at all*, counted over
:data:`HISTORY_DAYS` by the code that already owns each count — ``analytics.baselines``
for a daily metric (#89's own ``Baseline.n``, sentinel-filtered) and
``analytics.series.event_days`` for a logged event kind. Nothing new counts anything here.

EXISTENCE deliberately, not recency and not the context window. A 14-day coverage figure
would refuse a TRUE sentence sourced from a 30-day ``query_metric`` call, and whether a
stored value still speaks for today is ``derive.freshness``'s question, answered there.
This gate refuses one thing: describing data that is not there.

## What it CANNOT catch — the floor, said plainly

  * **A model that fabricates prose AND under-declares.** The declaration is the
    mechanism; a payload saying ``asserts: []`` beside prose describing a drink defeats
    it. :func:`_recorded_mentions` narrows that hole and does not close it.
  * That backstop is TEXTUAL, and only as good as a subject's name being a word prose
    actually uses. It fires for the logged event kinds (``alcohol``, ``caffeine``, …) and
    effectively never for a metric key — nobody writes "your rhr_daily was 54". A
    fabricated *metric* value is caught by the declaration or not at all.
  * **A subject we cannot count is not judged.** An unrecognised name is left out rather
    than assumed empty: inventing a verdict about a name we do not know would be the same
    guess this gate exists to refuse.
  * It says nothing about a value being WRONG — only about it not existing. An invented
    number for a metric the owner does have is invisible here.

Nothing here validates or ships. The surface gathers the two facts only it can (its owner,
its own payload); the rule and its wording live here; ``pipeline._personal_claim_gate``
runs it inside the shared registry, so a hit is nudged once and then falls back honestly
exactly like a missing citation.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Iterator, Sequence
from uuid import UUID

from healthee.analytics.baselines import compute_baselines_cur
from healthee.analytics.metrics import EVENT_KINDS, V2_DAILY_METRICS
from healthee.analytics.series import event_days
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.insights.answer_text import sentence_units

log = get_logger(__name__)

# The window "has this owner got any of this at all" is answered over. A year rather than
# the context window on purpose (see the docstring): this gate is about existence, and a
# short window would refuse true sentences sourced from a wider tool call.
HISTORY_DAYS = 365

# A sentence RECORDING something as having happened to the owner. Deliberately five
# past-tense reporting verbs in the second person and nothing looser: "you should stop
# caffeine 8 hours before bed" and "you need 150 minutes of exercise" are advice ABOUT a
# subject, not claims that it is in the data, and a backstop that ate those would block
# honest cited answers — the failure mode this gate must not have.
_RECORDED_RE = re.compile(
    r"\byou(?:'ve|\s+have)?\s+(?:logged|recorded|drank|consumed|took)\b",
    re.IGNORECASE,
)

# What makes a sentence a statement of ABSENCE. This is the crux in one regex: it is why
# "You have 0 logged alcohol entries in your history." stays shippable.
_ABSENCE_RE = re.compile(
    r"\b(?:0|zero|no|none|not|never|nothing|without|lack\w*|missing|any)\b|n['’]t\b",
    re.IGNORECASE,
)


def subjects_without_data(
    user_id: UUID, tz: str, asserted: Sequence[str], text: str
) -> frozenset[str]:
    """The subjects this answer talks about that the owner has NO stored data for.

    The one call that reads the database, made by the surface at judgement time. It is
    free for the common answer: a reply that declares no subject and records no event
    kind produces no candidates, and :func:`_days_with_data` returns before opening a
    connection. Re-read per attempt rather than cached, because ``log_entry`` can run
    mid-turn and a cached empty would then refuse a claim that had just become true.
    """
    candidates = _candidates(asserted, text)
    if not candidates:
        return frozenset()
    empty = frozenset(
        subject for subject, days in _days_with_data(user_id, tz, candidates).items() if days == 0
    )
    if empty:
        log.info("coach answer touches subjects with no stored data: %s", sorted(empty))
    return empty


def issues(text: str, asserted: Sequence[str], without_data: frozenset[str]) -> tuple[str, ...]:
    """Every personal claim this answer makes about data the owner does not have.

    Declared assertions first — that is the structural check, and its message names the
    subject the model itself put in the payload. Then the textual backstop, skipped for
    any subject already reported so one defect is never nudged as two.
    """
    if not without_data:
        return ()
    reported: set[str] = set()
    found: list[str] = []
    for subject in _normalized(asserted):
        if subject in without_data and subject not in reported:
            reported.add(subject)
            found.append(_declared_issue(subject))
    for subject, sentence in _recorded_mentions(text, without_data):
        if subject in reported:
            continue
        reported.add(subject)
        found.append(_recorded_issue(subject, sentence))
    return tuple(found)


def _declared_issue(subject: str) -> str:
    """The nudge for a declared assertion — names the subject and its zero."""
    return (
        f"Asserted a value for `{subject}`, but this owner has 0 days of {subject} in the "
        f"last {HISTORY_DAYS} days. Say plainly that there is none; do not describe one."
    )


def _recorded_issue(subject: str, sentence: str) -> str:
    """The nudge for a sentence that records an event the data has no trace of."""
    return (
        f"States {subject} as something that happened — '{sentence[:120]}' — but this owner "
        f"has 0 days of {subject} on record. Say there is none, or drop the sentence."
    )


def _candidates(asserted: Sequence[str], text: str) -> tuple[str, ...]:
    """The subjects worth counting: everything declared, plus event kinds the prose RECORDS.

    The second half is what keeps the backstop independent of the declaration — an answer
    that fabricates a drink and declares nothing still gets its claim counted — and it is
    also what keeps the gate free, because an answer doing neither reaches no query.
    """
    named = sorted({subject for subject, _ in _recorded_mentions(text, EVENT_KINDS)})
    return tuple(dict.fromkeys([*_normalized(asserted), *named]))


def _normalized(subjects: Sequence[str]) -> list[str]:
    """Declared subjects as comparable keys — the model's spacing is not a verdict."""
    return [subject.strip().lower() for subject in subjects if subject and subject.strip()]


def _recorded_mentions(text: str, subjects: Iterable[str]) -> Iterator[tuple[str, str]]:
    """``(subject, sentence)`` for each sentence recording one of ``subjects`` as happened.

    Sentence-scoped on both halves: the reporting verb and the subject must appear in the
    same sentence, which is a cheap stand-in for "this verb is about this subject" and
    keeps a research sentence in the next bullet out of it entirely.
    """
    for unit in sentence_units(text):
        if not _RECORDED_RE.search(unit.text) or _ABSENCE_RE.search(unit.text):
            continue
        for subject in subjects:
            if _mentions(unit.text, subject):
                yield subject, unit.text


def _mentions(sentence: str, subject: str) -> bool:
    """Whether ``sentence`` names ``subject`` as a word (``sleep_debt_min`` → "sleep debt min")."""
    return re.search(rf"\b{re.escape(subject.replace('_', ' '))}\b", sentence, re.I) is not None


def _days_with_data(user_id: UUID, tz: str, subjects: Sequence[str]) -> dict[str, int]:
    """Days of data per subject, counted by whichever module already owns that count.

    Two tables, two owners, ONE definition of "has data" per table — no SQL is written
    here. A subject in neither registry is omitted rather than returned as 0: the honest
    answer to "how many days of it do we have" is "we do not know what that is".
    """
    metrics = [s for s in subjects if s in V2_DAILY_METRICS]
    events = [s for s in subjects if s in EVENT_KINDS]
    if not metrics and not events:
        return {}
    counted: dict[str, int] = {}
    with tenant_transaction(user_id) as cur:
        if metrics:
            baselines = compute_baselines_cur(cur, user_id, tz, metrics, HISTORY_DAYS)
            counted.update({metric: baselines[metric].n for metric in metrics})
        counted.update({kind: len(event_days(cur, user_id, tz, kind)) for kind in events})
    return counted
