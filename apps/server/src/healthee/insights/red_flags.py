"""Exertional red flags — ONE vocabulary, asked from BOTH sides of the exchange (#106).

Until now these words existed on one side only. ``guard_directives`` compiled
environmental_stress D12 (#100) and taught the product to recognise confusion, collapse,
vomiting, seizure, ataxia and heat stroke — but only in the MODEL'S OUTPUT, as the
subject gate of a rule about what the coach may not *say*. ``refusals.py``, the pre-LLM
screen that reads the OWNER'S QUESTION, knew "chest pain" and "faint" and nothing else.

Driving prod on 2026-08-01 found the hole that leaves. Asked *"During my long run
yesterday I got confused and started vomiting, then collapsed. Was that just dehydration?
Should I run again tomorrow?"* — the textbook presentation of exertional heat stroke,
where outcome is measured in minutes of cooling delay — the coach came back
``refused=False`` twice. Neither answer was dangerous (D12 would have blocked one that
was); neither ESCALATED. D12 cannot fire when the owner reports the emergency and the
model's reply happens to be innocuous, because D12 reads the reply.

So this module holds the words, and both sides import them:

  * :data:`EXERTIONAL_RED_FLAG_RE` — what an exertional red flag looks like in text.
    ``guard_directives`` uses it as D12's SUBJECT ("is this answer about one?");
    :func:`owner_reports_emergency` uses it to ask a different question ("is the owner
    REPORTING one?").
  * :data:`EXERTION_OR_HEAT_RE` — the exercise-or-heat context that makes those signs an
    emergency rather than a symptom list. It is D12's own scope ("during/after hot
    exercise") and it already gated ``hydration_everyday`` D5.

One copy, because two copies is the defect class this repo has been burned by twice —
``evidence_grade`` vs ``grade`` (#83) and ``GRADE_RANK`` duplicated into ``analytics``
(#88). A safety vocabulary that can drift between the question screen and the output
guard would be the same bug with a worse blast radius.

## What each side adds, and why the gating is NOT shared

The words are shared; the *gating* is not, and that is deliberate. The two sides are
asking different questions and their cost matrices differ:

  * the output guard adds a FORBIDDEN MOVE (reassure / explain away / brush off / coach
    on through) and a negation window — "you should not push through this" is the
    opposite of the violation, so a negator has to cancel it;
  * this screen adds an OWNER REPORT — the sign has to be attributed to the owner as
    something that happened, in an exercise-or-heat context.

Notably this screen does **not** honour ``guard_rules.NEGATOR_RE``. On the answer side a
negator flips the meaning. On the question side a negated red flag from a frightened
person is far more often uncertainty than absence — *"I don't know if I passed out"*,
*"I can't remember if I collapsed"* — and "can't remember" is itself a red flag. Reading
those as denials would be a false PASS, which is the one error this file may not make.

## Provenance (Engineering Standards §4: a guardrail needs a documented origin)

``environmental_stress`` D12 (SAFETY-CRITICAL) — "on heat-illness red flags (confusion,
collapse, disorientation, vomiting, altered behavior) during/after hot exercise, stop
training advice and direct the runner to immediate cooling and urgent medical care" —
plus D13 (altitude illness) and ``fueling_and_hydration`` D12 (EAH), which state the same
forbidden move and defer to it. INTELLIGENCE §3 step 1 / §5.5 is what makes the question
side the right place: a screened question never reaches the model, so nothing can be
prompted, jailbroken or cajoled past it.

## The other harm, which is real

An over-broad emergency screen trains people to ignore the escalation and makes the
product useless — so every ordinary training question must survive it. The boundary is
pinned case-by-case in ``tests/insights/test_exertional_question_screen.py``, one case per
alternative, and the four disqualifiers below each exist because a specific honest
sentence would otherwise be refused. Where a case could not be separated cleanly it is
left firing and said so out loud, because a stated over-refusal beats a bad heuristic.
"""

from __future__ import annotations

import re

from healthee.insights.answer_text import sentences
from healthee.insights.guard_rules import rx

__all__ = ["EXERTIONAL_RED_FLAG_RE", "EXERTION_OR_HEAT_RE", "owner_reports_emergency"]


# ── The shared vocabulary ────────────────────────────────────────────────────
# Exercise-or-heat context. This is D12's own scope: the same signs away from exertion
# are an ordinary symptom list, and it is the effort or the heat that turns them into
# heat stroke / exercise-associated hyponatraemia / altitude illness. Also the subject
# gate of `hydration_everyday` D5, which is why it lives here rather than in either
# consumer.
EXERTION_OR_HEAT_RE = rx(
    r"\b(?:run|runs|running|ride|riding|cycl\w+|swim\w*|workout|work\s?out|training|"
    r"train|session|race|racing|marathon|half\b|10k|5k|exercis\w+|long\s+run|hike|"
    r"hiking|effort|interval)\w*\b",
    r"\b(?:heat|hot\s+(?:weather|day|conditions)|humid\w*|WBGT|heatwave|sweat\w*|"
    r"warm\s+conditions)\b",
)

# The red flags themselves. Deliberately person-attributed or unambiguously clinical: a
# bare `\bconfusion\b` would fire on "there is some confusion about what HRV measures",
# an honest sentence, and an over-broad safety filter that eats honest science is its own
# harm. Every alternative carries a case of its own in the tests of BOTH consumers.
EXERTIONAL_RED_FLAG_RE = rx(
    r"\bheat\s*(?:stroke|exhaustion|illness)\b",
    r"\bhyponatr\w+\b",
    r"\b(?:HAPE|HACE)\b",
    r"\baltitude\s+(?:illness|sickness)\b|\bacute\s+mountain\s+sickness\b",
    r"\bseizur\w+\b|\bconvuls\w+\b|\bfit(?:ting)?\s+during\b",
    r"\bataxi\w+\b|\bstaggering\b|\bcouldn'?t\s+walk\s+straight\b",
    r"\baltered\s+(?:consciousness|mental\s+stat\w+|behaviou?r)\b",
    r"\bunresponsive\b|\bpassed\s+out\s+(?:during|after)\b",
    r"\bcollapsed?\b(?=[^.]{0,60}\b(?:run|race|training|session|heat|hot|ride|effort)\w*\b)",
    r"\b(?:was|were|is|are|got|getting|gets|became|becoming|feeling|felt|seem(?:ed|s)?|"
    r"going|went)\s+"
    r"(?:very\s+|really\s+|quite\s+|a\s+bit\s+|increasingly\s+)?"
    r"(?:confused|disorient\w+|delirious|incoherent)\b",
    r"\b(?:vomit\w+|threw\s+up|throwing\s+up|being\s+sick)\b",
    r"\bstopped\s+sweating\b|\bhot,?\s+dry\s+skin\b",
    # Qualified only. A bare `\bheadache\b` would block "a headache after a hot long run
    # is common" — an honest sentence. `severe`/`worsening` is what turns it into the
    # HACE / hyponatraemia presentation the directive is about.
    r"\b(?:severe|worsening|blinding|thunderclap)\s+headache\b",
)


# ── The question side: is the OWNER reporting one of these? ──────────────────
# The discriminator is grammatical, not lexical, and it has to be: the same words appear
# in a report ("I collapsed during my run yesterday") and in a question about the topic
# ("should I worry about hyponatraemia on my long run?"). What separates them is whether
# the sign is attributed to the owner as something that HAPPENED.
#
# Two shapes, because the vocabulary holds two kinds of alternative:
#   * verb-phrase red flags ("got confused", "threw up", "collapsed") already carry the
#     verb, so they need only an "I" immediately in front — the second alternative;
#   * noun red flags ("heat stroke", "a seizure", "hyponatraemia") need an experience
#     verb ("I had", "I got", "I ended up with") — the first.
# The window is tight and clause-scoped (`[^.;:?!]`) for the same reason
# `guard_rules.NEGATOR_RE` is: a loose window stops meaning anything. "Should I worry
# about hyponatraemia" and "I read about heat exhaustion" both fail both alternatives,
# which is the whole point.
_OWNER_EXPERIENCE_RE = re.compile(
    r"(?:\bI\b[^.;:?!]{0,4}\b(?:was|were|am|got|get|gets|had|have|has|feel|feels|felt|"
    r"start|starts|started|begin|began|keep|keeps|kept|end|ends|ended|go|went|come|came|"
    r"throw|threw|vomited|collapsed|passed|blacked|stopped|become|became|seem|seemed|"
    r"remember|woke|ended\s+up)\b[^.;:?!]{0,30}"
    r"|\bI\b[^.;:?!]{0,3})$",
    re.IGNORECASE,
)

# Disqualifier 1 · the owner is saying the sign did NOT happen. Only the unambiguously
# counterfactual phrasings — "I felt like vomiting the whole last mile" is hyperbole for
# a hard effort, not a report of vomiting. "Nearly" and "almost" are deliberately ABSENT:
# "I almost passed out at mile 20" is presyncope, and refusing it is the right outcome.
_HEDGED_RE = re.compile(
    r"(?:\b(?:felt|feel|feels|feeling)\s+like\b"
    r"|\bthought\s+I\s+(?:was|might|would|could)\b"
    r"|\bwanted\s+to\b"
    r"|\bas\s+if\s+I\b)[^.;:,?!]{0,30}$",
    re.IGNORECASE,
)

# Disqualifier 2 · "I collapsed onto the sofa after my run" is the ordinary English idiom
# for sitting down heavily, and it satisfies D12's collapse alternative exactly (the
# lookahead only asks for an effort word within 60 characters, which "after my run"
# supplies). Furniture is the tell. Ground/floor/grass are deliberately NOT here: a
# runner on the floor after a race is the presentation, not the idiom.
#
# This lives on the question side only. Narrowing D12's shipped subject would be a
# behaviour change to a live output guardrail, and per `guard_rules`' own note that does
# not get to happen as a side effect of adding a different rule.
_BENIGN_COLLAPSE_RE = re.compile(
    r"^\s*(?:down\s+)?(?:onto|on|into|in)\s+(?:the|my|a|his|her|their)\s+"
    r"(?:sofa|couch|settee|armchair|bed|chair|seat|cushions?|beanbag)\b",
    re.IGNORECASE,
)

# Disqualifier 3 · past clinical history is a real question deserving a real answer:
# "I had a seizure disorder as a child, is running safe?" is not an emergency report.
# Scoped to the same clause and to a 50-character window after the sign, so that "I have
# a history of low iron and I collapsed during my run yesterday" is untouched — the
# marker has to attach to the SIGN, not merely appear in the message.
_LONG_PAST_RE = re.compile(
    r"^[^.;:?!]{0,50}\b(?:as\s+a\s+(?:child|kid|teenager|teen|youngster|boy|girl)"
    r"|when\s+I\s+was\s+(?:a\s+)?(?:child|kid|young|little|\d+)"
    r"|(?:years|decades)\s+ago"
    r"|growing\s+up"
    r"|in\s+(?:my\s+(?:teens|twenties|childhood)|childhood))\b",
    re.IGNORECASE,
)

# Disqualifier 4 · the habitual/general question. "Why do I keep vomiting after my long
# runs?" is a pattern question about exercise-induced GI distress, not an acute report,
# and a person asking to LEARN is not a person reporting an emergency. Present-tense
# generic auxiliaries only: "why DID I collapse during my run yesterday?" is a report
# wearing a question mark and must still escalate.
_GENERAL_QUESTION_RE = re.compile(
    r"^\s*(?:so\s+|and\s+|but\s+|also\s+)?why\s+(?:do|does|would|can|is|are)\b",
    re.IGNORECASE,
)


def owner_reports_emergency(question: str) -> bool:
    """True when the owner is reporting an exertional red flag about themselves.

    Requires an exercise-or-heat context anywhere in the message (D12's own scope) and at
    least one sentence carrying an owner-attributed red flag. Sentence-scoped for the
    report, message-scoped for the context, because people split the two across sentences
    — "I did a long run yesterday. Halfway through I got confused and threw up."
    """
    if not EXERTION_OR_HEAT_RE.search(question):
        return False
    return any(_reports_red_flag(sentence) for sentence in sentences(question))


def _reports_red_flag(sentence: str) -> bool:
    """True when this one sentence is an owner report rather than a question about it."""
    if _GENERAL_QUESTION_RE.search(sentence):
        return False
    return any(_is_owner_report(sentence, m) for m in EXERTIONAL_RED_FLAG_RE.finditer(sentence))


def _is_owner_report(sentence: str, sign: re.Match[str]) -> bool:
    """True when this ONE occurrence of a red flag is attributed to the owner as real."""
    before, after = sentence[: sign.start()], sentence[sign.end() :]
    if not _OWNER_EXPERIENCE_RE.search(before):
        return False
    if _HEDGED_RE.search(before):
        return False
    return not (_BENIGN_COLLAPSE_RE.match(after) or _LONG_PAST_RE.match(after))
