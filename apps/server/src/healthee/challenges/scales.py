"""The two per-metric numeric SCALES the adapter moves a live target by.

Split from :mod:`healthee.challenges.metrics` because they answer a different question
and change for a different reason (standards §"a file has one reason to change"): that
module says which metrics a challenge may bind to and where each one's daily value comes
from, this one says **how far** the engine may move a target unattended (:data:`IDEAL`)
and **how finely** (:data:`ROUND_STEP`). Both are ported verbatim from legacy — nothing
here is new, and the argument attached to each table is unchanged.

The split is also what keeps the registry inside the 400-line gate now that it carries
the generated windowed catalogue; every existing import site was updated rather than
re-exported, so there is exactly one place each table is defined and one place it is
imported from.
"""

from __future__ import annotations

from healthee.challenges.metrics import WINDOW_BASES
from healthee.challenges.windowed import WINDOW_HOURS, metric_key

__all__ = ["IDEAL", "ROUND_STEP", "round_target"]

# Evidence "ideal" per metric — the CEILING the adapter may never raise a target
# past (`adapt.suggest_adaptation`). Values verbatim from legacy `_IDEAL` (:148);
# the citations are this port's addition (standards §"every constant derived from
# research cites its note"). A metric absent here has no ceiling, exactly as in
# legacy — `active_calories` and `cardio_load` are individual-load quantities with
# no population target to anchor one, so none was invented.
#
# ⚠ A CITATION IS A CLAIM ABOUT A LINE IN A NOTE (#67). `sri` carried 85.0 with
# "[sleep_regularity_index]" beside it and **85 appears nowhere in that note**. What the
# note pins is `SRI_GOOD = 70.0` (the same threshold the 4-dim regularity dimension
# already gates on) and, descriptively, the UK Biobank cohort's median of 81.0
# [IQR 73.8-86.3]. A cohort's median or upper quartile says what is TYPICAL, not what is
# good, so neither is a target either; 70 is the only "good" figure the corpus states.
# The value is now that number, and the citation is true.
#
# ⚠ WHAT 70 RESTS ON, checked against the paper (#81, 2026-08-01). It is DERIVED, not
# published: Windred 2024 states no cutoff of 70 — its least-regular quintile is
# SRI < 71.6, and 70 is that boundary rounded down. The note's old justification ("the
# Q4/Q3 boundary") was false (that boundary is ~83). So this entry is still the corpus's
# one "good" SRI figure, but it is a rounded operationalisation, not a research finding;
# whether it should be 71.6 is a science-constant change and its own PR.
#
# A target and a ceiling are different questions, and they stay different tables
# (`challenges/targets.py` argues why). But they may not be different NUMBERS for one
# metric unless the corpus supplies two — "how regular is regular enough" has one answer
# or the product has two definitions of good SRI (CLAUDE.md §ONE canonical definition).
# `test_registry` pins the agreement for every metric that appears in both tables.
#
# The 85 was live, not cosmetic: generation caps a proposed target at the evidence target
# (`bounds.band_for`), so the engine refused to PROPOSE an SRI target above 70 and would
# then ratchet an adopted one to 84 unattended. Stopping at the evidence target is what
# `mvpa_min` already does at 150 — a number its own note calls "a floor, not a ceiling" —
# so this is the existing rule applied, not a new one.
#
# Removing `sri` from this table would NOT have meant "do not raise": `adapt._ceiling`
# falls back to `OWNER_CEILING_FACTOR x baseline` whenever a baseline exists, which on a
# bounded 0-100 index yields ceilings above 100 (74 x 1.5 = 111). An owner-relative
# multiple is meaningless for a score, which is the other reason `sri` keeps an entry.
IDEAL: dict[str, float] = {
    "mvpa_min": 150.0,  # WHO weekly MVPA target [mvpa_minutes_mortality]
    "steps_total": 8000.0,  # daily-steps mortality plateau [steps_mortality]
    "tst_min": 450.0,  # 7.5 h, mid-band of the U-curve [sleep_duration_mortality]
    "sri": 70.0,  # `SRI_GOOD`, derived from Windred 2024 [sleep_regularity_index]
    # NOT EVIDENCE, and it must never be presented as such. No note in the corpus
    # supports a specific weekly SESSION count — the evidence is denominated in
    # minutes, not sessions — so this is practitioner consensus with no citation
    # behind it. It exists solely as `adapt._raise_to`'s ceiling (a guard on how far
    # the engine may move a target by itself) and is never read by a surface that
    # shows the owner a target, a rationale, or a research note.
    "workouts_week": 4.0,
    # The cap metrics are deliberately absent: IDEAL is the ceiling on RAISING a
    # target, and a `good="down"` metric has no ceiling to raise toward. Their
    # adapter guard is `adapt.OWNER_CEILING_FACTOR` (owner-relative), if it ever
    # applies at all — `suggest_adaptation` leaves `<=` challenges alone.
}

# Rounding granularity per metric, so an adapted target stays a human number
# ("8,000 steps", not "7,943"). Verbatim from legacy `_ROUND_STEP` (:536).
ROUND_STEP: dict[str, float] = {
    "steps_total": 250,
    "mvpa_min": 5,
    "tst_min": 5,
    "sri": 1,
    "workouts_week": 1,
    "active_calories": 10,
    "cardio_load": 5,
    "alcohol_units": 1,  # a UK unit is the smallest meaningful step
    "caffeine_mg": 25,  # ~a quarter of a filter coffee; "200 mg", not "187 mg"
}

# A window rounds like the quantity it is a slice of. Taken from the base entry rather
# than restated, because two steps for one unit is two answers to "what is a human
# number of milligrams" — and `bounds.band_for` uses the step as the floor on a move, so
# a divergence here would silently widen or narrow the band on the windowed metric only.
ROUND_STEP |= {
    metric_key(source.kind, hour): ROUND_STEP[base]
    for base, source in WINDOW_BASES.items()
    for hour in WINDOW_HOURS
}


def round_target(metric: str, value: float) -> float:
    """Round ``value`` to the metric's human step. Verbatim from legacy ``_round_target``."""
    step = ROUND_STEP.get(metric, 1)
    return float(round(value / step) * step)
