"""WITHHELD is not MISSING — and the prompt could not tell the model apart (#126).

## The defect

``derive/freshness.py`` computes, for four metrics, *why* there is no current value and
*what would restore it*: a reason id an operator can filter on and a second-person sentence
a person can act on. ``/api/today`` carries the whole ``withheld`` block. The LLM context
carried **a dash** — the same dash a metric gets when it was never synced, and the same
absence a metric gets when the owner has never had it at all. Three different states, one
character.

That is sharpest against ``docs/COACH_PROMPT.md``, which instructs the coach to say
*"'I don't have enough data to say' is always better than a confident guess. When coverage
is thin, say so **and say what you'd need**."* A persona asked for a behaviour its context
cannot support is resolved by the model — which is invention, dressed as helpfulness. It
also runs against the product's own line: *"not enough data beats an optimistic guess"* is
only honest if the surface talking to the owner can tell the two apart.

## What is carried, and what is deliberately NOT

The reason id and the metric's own restoring sentence — the two fields of ``withheld_block``
that mean something to a reader. Not ``last_as_of_date``, ``age_days`` or ``last_estimate``:
putting a withheld metric's last VALUE back into the prompt is exactly the resurrection the
withhold gate exists to prevent, and ``read/vo2max.py`` argues at length why a dated field
does not undo a confident-looking number. The block says a number is refused; it does not
then supply one.

The message is carried rather than left to the model because the reason id alone would make
the coach paraphrase ``profile_or_weight_missing`` into a remedy, and a paraphrased remedy
is a guess about our own gates. The sentences already exist, single-sourced in the derive
modules that own each gate (``WITHHOLD_MESSAGES``, ``SRI_MESSAGES``, ``SLEEP_DEBT_MESSAGES``)
— this module quotes them, it does not author a second vocabulary.

## Never-had-it stays absent, on purpose

A metric with no stored row at all is skipped: it is not withheld, it simply does not exist
for this owner, and ``read/vo2max.py`` draws the same line (``vo2max_payload`` returns
``None`` rather than a withhold when the window holds nothing). So the block's legend can
say what the remaining silence means, which is the third state the dash was hiding.

## Cost

The block rides in every prompt ``build_context`` feeds, and #105 established prompt size as
the dominant cost driver. Measured with tiktoken/cl100k_base over the REAL assembled coach
prompt (``coach._initial_messages``, the way #120 measured): **+0 tokens** when nothing is
withheld — the common case, because a row keyed to today short-circuits the gate before any
extra query runs — and **+128** for a seeded owner with a stale VO₂max and a refused SRI.
Against the 80,435-token coach question #105 measured that is **+0.16 %**. Block-only
arithmetic behind it: **43 fixed** (heading + legend) plus one metric's own sentence, so
**196** if all three gates refused at once with their longest reasons (**+0.24 %**).

Reason ids alone would have cost ~70 and were rejected: the coach would then have to
paraphrase ``profile_or_weight_missing`` into a remedy, which is a guess about our own
gates, and "say what you'd need" answered by invention is the failure this block exists to
close. ``tests/insights/test_context_withheld.py`` asserts the budget.

Recovery is the fourth gate and is NOT here: ``coach_context._recovery_block`` already
renders its staleness in the coach's own voice, with ``STALE_RECOVERY_DIRECTIVE``. Adding
it would be a second answer to a question that already has one.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass
from datetime import date
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.derive.sleep_score import (
    SLEEP_DEBT_MESSAGES,
    SRI_MESSAGES,
    sleep_debt_unavailable_reason,
    sri_unavailable_reason,
)
from healthee.derive.vo2max import WITHHOLD_MESSAGES
from healthee.derive.vo2max_tier import estimate_unavailable_reason

log = get_logger(__name__)

# "Why is there no value for TODAY" — the consumer-facing question, one signature.
_ReasonOf = Callable[[Cur, UUID, str, date, date | None], "str | None"]


@dataclass(frozen=True)
class _Gate:
    """One metric's withhold gate: the reason resolver, and the sentences it can return.

    Both halves belong to the ``derive`` module that owns the metric. Nothing is defined
    here — a reason vocabulary maintained in two places is how "what would restore this"
    starts disagreeing with the gate that refused.
    """

    reason_of: _ReasonOf
    messages: Mapping[str, str]


_GATES: Mapping[str, _Gate] = {
    "vo2max_estimate": _Gate(estimate_unavailable_reason, WITHHOLD_MESSAGES),
    "sleep_regularity_index": _Gate(sri_unavailable_reason, SRI_MESSAGES),
    "sleep_debt_min": _Gate(sleep_debt_unavailable_reason, SLEEP_DEBT_MESSAGES),
}

# The heading and the legend are the block's only FIXED cost — they ride whenever anything
# is withheld, whatever it is — so they are as short as three states can be told apart in:
# refused (listed here), never recorded (absent, and the legend says so), and stale (the
# gates' own NOT_DERIVED_YET reason, which reads "sync the strap"). 43 cl100k tokens.
_HEADING = "## Withheld today — refused by a gate, NOT missing data"
_LEGEND = (
    "Anything else absent above was never recorded. Never present an older value as today's "
    "here; say what is missing and quote the restoring step given."
)


def withheld_section(cur: Cur, user_id: UUID, tz: str) -> str:
    """The metrics a gate is refusing to produce today, each with what would restore it.

    ``""`` when nothing is withheld, which is the common case and costs nothing. Gates are
    re-run rather than persisted, exactly as the read layer runs them
    (``read/vo2max.py``): the inputs are still in the database, so there is no migration,
    no backfill, and no second answer to keep in step.
    """
    today = user_today(tz)
    newest = _newest_days(cur, user_id)
    lines = [
        entry
        for metric, gate in _GATES.items()
        if (entry := _entry(cur, user_id, tz, today, newest, metric, gate))
    ]
    if not lines:
        return ""
    return "\n".join([_HEADING, *lines, _LEGEND])


def _entry(  # noqa: PLR0913 — one line's worth of state, threaded rather than re-queried
    cur: Cur,
    user_id: UUID,
    tz: str,
    today: date,
    newest: Mapping[str, date],
    metric: str,
    gate: _Gate,
) -> str:
    """One metric's line, or ``""`` when it has a current value — or never had one at all."""
    last_day = newest.get(metric)
    if last_day is None:
        return ""  # never recorded: absent, not refused (see the module docstring)
    reason = gate.reason_of(cur, user_id, tz, today, last_day)
    if reason is None:
        return ""
    message = gate.messages.get(reason)
    if message is None:
        # The gate named a state its own message table does not cover. Say less rather
        # than inventing a remedy, and log it — a silent fallback here would hide a
        # vocabulary that had drifted out of step with its gate.
        log.warning("withheld reason has no message: metric=%s reason=%s", metric, reason)
        return f"- {metric}: {reason}"
    return f"- {metric}: {reason} — {message}"


def _newest_days(cur: Cur, user_id: UUID) -> dict[str, date]:
    """The newest stored day per gated metric — one grouped query, no per-metric probe.

    Absent from the result means the owner has NO row for that metric, ever, which is the
    one state this block must stay silent about.
    """
    cur.execute(
        "SELECT metric, MAX(day) FROM derived_daily WHERE user_id = %s AND metric = ANY(%s) "
        "GROUP BY metric",
        (user_id, list(_GATES)),
    )
    return {row[0]: row[1] for row in cur.fetchall() if row[1] is not None}
