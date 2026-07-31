"""The deterministic recovery guidance text, and the band vocabulary it keys on.

Split from :mod:`healthee.read.recovery` (standards §1: a file has one reason to change,
and that one was at the 400-line gate). What lives here is the *rule-based prose* — the
band a score falls in, the sentence each band gets, the illness override that replaces it,
and the tail naming the limiting factor. None of it is LLM: legacy generated this string
in-process without a model, and it ports verbatim.

The band mapping is public because a SECOND caller needs it. ``challenges/levers.py``
withholds hard training levers from an under-recovered owner, and "under-recovered" must
mean exactly what the Today page means by it rather than a second set of cut points
(standards §Duplication: second occurrence = extract).
"""

from __future__ import annotations

from healthee.core.logging import get_logger

log = get_logger(__name__)

_BASE_GUIDANCE = {
    "high": "Well recovered — a good day to push: intervals or a harder session are on the table.",
    "moderate": "Moderate readiness — keep it easy-to-moderate (Zone 2 / brisk). "
    "Skip a hard session today.",
    "low": "Low readiness — prioritise recovery: easy movement only, and protect tonight's sleep.",
}
# An active illness flag OVERRIDES the band. The flag exists precisely to catch what a
# recovery score misses — respiratory rate and skin temperature move first, and the
# score does not weight them the way an infection does — so a "high" band must never
# clear a flagged owner to push. Without this, `/api/today` told an actively-flagged
# owner "a good day to push" in the SAME payload that rendered their illness card.
# Sourced: sports-science COACHING-RULES.md rule 6 ("Illness pause ... do not train
# through it — default to rest ... Illness symptoms veto hard training regardless of
# fresh form") and rule 13 ("readiness hard overrides are not votes ... never let
# high/green readiness clear a runner reporting illness").
# The recovery NUMBER is never dropped: the payload still reports `recovery` and `band`
# (hiding a measured number would be its own dishonesty). Only the GUIDANCE changes.
# [[respiratory_rate_normal]], [[skin_temp_signals]]
_ILLNESS_GUIDANCE = {
    "high": "An illness signal is active — it overrides today's recovery number. Rest "
    "today: easy movement at most, nothing hard, and protect tonight's sleep. "
    "Not a diagnosis.",
    "moderate": "An illness signal is active — it overrides today's recovery number. "
    "Keep today easy and skip anything hard until the signal clears. Not a diagnosis.",
}
# The go / modify / rest cut points, in `recovery_score` units. [[recovery_readiness]]
# expresses readiness as that three-way band; these thirds are the shipped rendering of it
# and are ported from legacy. They live as named constants with a function over them
# because a SECOND caller now needs the same three words: WP-C3c's lever ranking withholds
# hard training levers from an under-recovered owner, and "under-recovered" must mean
# exactly what the Today page means by it (standards §Duplication: second occurrence =
# extract).
RECOVERY_HIGH_FROM = 67
RECOVERY_MODERATE_FROM = 34
_FACTOR_TAILS = {
    "sleep": " Short sleep is the main drag — an earlier night is your highest-leverage move.",
    "hrv": " HRV is below your baseline — your nervous system is still catching up.",
    "rhr": " Resting HR is up vs baseline — could be early strain or illness, so go easy.",
    "rr": " Breathing rate is elevated vs baseline — a possible early strain/illness signal; "
    "ease off.",
}


def recovery_band(score: float) -> str:
    """``"high"`` / ``"moderate"`` / ``"low"`` for a recovery score — the ONE mapping."""
    if score >= RECOVERY_HIGH_FROM:
        return "high"
    return "moderate" if score >= RECOVERY_MODERATE_FROM else "low"


def _base_guidance(band: str, illness: str | None) -> str:
    """The guidance ceiling: an active illness flag replaces the band's text entirely."""
    if illness is None:
        return _BASE_GUIDANCE[band]
    override = _ILLNESS_GUIDANCE.get(illness)
    if override is None:
        # Unreachable: the schema CHECK-constrains severity to moderate|high. But an
        # unrecognised severity must fail SAFE (toward rest), never fall through to "a
        # good day to push" — that silent fall-through is the bug this function fixes.
        log.warning("unknown illness severity %r — using the strictest guidance", illness)
        return _ILLNESS_GUIDANCE["high"]
    return override


def daily_guidance(
    band: str, readiness: int, recovery: int, factors: dict, illness: str | None
) -> str:
    """Deterministic, evidence-grounded daily guidance (NOT LLM): the band sets the
    ceiling — unless an active illness flag overrides it (see ``_ILLNESS_GUIDANCE``) —
    and the lowest-scoring factor names the lever. Band/tail logic ported VERBATIM."""
    tail = ""
    limiter = min(factors.items(), key=lambda kv: kv[1].get("sub", 50)) if factors else None
    if limiter and limiter[1].get("sub", 50) < 45:
        tail = _FACTOR_TAILS.get(limiter[0], "")
    if readiness < recovery - 8:
        tail += " Today's training has already used some of your capacity."
    return _base_guidance(band, illness) + tail
