"""``vo2max_estimate`` is ONE metric with three instruments in the notes' order (#117).

Three notes specify a tiered metric and the code implemented no precedence at all:

    [[submaximal_vo2max]] D1  — the submaximal estimate is the **primary**
                                ``vo2max_estimate`` path, "otherwise fall back to
                                [[non_exercise_vo2max]]"
    [[hr_reserve_vo2max]] D2  — the reserve inversion runs "only as the fallback when the
                                graded fit cannot fit a line"
    [[hr_reserve_vo2max]] D4  — "**Never average the two methods.** They are different
                                instruments; a blended number has no validation behind
                                it. State which one produced the value."
    [[non_exercise_vo2max]] D1 — Jurca runs "only as the **fallback**"

Every number below is a real one. The two measured values are this owner's own, out of
production on 2026-08-02 and pinned independently against the real recorded track in
``test_vo2max_golden_track.py``; the Jurca value is the note's own worked check. None of
them was read back out of the implementation.
"""

from __future__ import annotations

from datetime import date, timedelta
from itertools import permutations

import pytest

from healthee.derive.freshness import MEASURED_VO2MAX_MAX_AGE_DAYS
from healthee.derive.vo2max import _vo2max_jurca
from healthee.derive.vo2max_reserve import METHOD_RESERVE
from healthee.derive.vo2max_submax import METHOD_GRADED
from healthee.derive.vo2max_tier import (
    MEASURED_PRECEDENCE,
    MeasuredSession,
    select_measured_tier,
)

# ── the real numbers this file pins ──────────────────────────────────────────
#
# The graded HR-vs-workload fit on the owner's 2026-06-15 recorded session. Pinned from
# the real track in ``test_vo2max_golden_track.py::GRADED_VO2MAX`` and reported in
# docs/CADENCE_VO2MAX_FEASIBILITY.md §1.1.
GRADED_VALUE = 39.6
# The %HRR inversion on his 2026-06-18 session (a different day, and the second of the
# only two sessions of his that either instrument could score at all).
RESERVE_VALUE = 41.7
# The Jurca model for this same owner at his own answered SR-PA of 0, from
# [[non_exercise_vo2max]]'s worked check: 32, male, BMI 25.2, RHR 58.4 →
# 18.07 + 2.77 − 3.20 − 4.284 − 1.752 = 11.604 METs × 3.5 = 40.6 ml/kg/min.
JURCA_VALUE = 40.6
# FRIEND's published 50th percentile for a 30–39 male (Kaminsky 2022, Table 3) — what all
# three of the above are read against, and the reason the fallback's 40.6 is "average"
# rather than "fit".
KAMINSKY_MEDIAN_30S_MALE = 39.7

# What a BLEND of the two measured values would produce. It is here to be excluded, and
# it is worth seeing why it would be so hard to spot in production: the average of the
# owner's two measured values is 40.7, within 0.1 of the 40.6 his non-exercise fallback
# returns. A blended number would sit where a correctly-tiered one plausibly could, so
# nobody would catch it by looking — which is why D4 is enforced structurally below and
# not by review.
_BLEND_OF_THE_TWO = round((GRADED_VALUE + RESERVE_VALUE) / 2, 1)


def test_the_owners_three_instruments_are_the_numbers_this_file_claims() -> None:
    """Guard the guards. If these move, every precedence assertion below is about
    something other than the owner's real data."""
    assert _vo2max_jurca(32, "male", 25.2, 58.4, 0) == pytest.approx(JURCA_VALUE, abs=0.05)
    assert GRADED_VALUE < KAMINSKY_MEDIAN_30S_MALE < JURCA_VALUE < RESERVE_VALUE
    assert _BLEND_OF_THE_TWO == 40.7  # one tenth from the fallback — the near-coincidence


# ── the precedence, and the guarantee that nothing blends ────────────────────


def _session(method: str, days_ago: int, value: float, hrr: float | None = None) -> MeasuredSession:
    return MeasuredSession(
        day=_TODAY - timedelta(days=days_ago), value=value, method=method, hrr_median=hrr
    )


_TODAY = date(2026, 8, 2)


def test_the_graded_fit_wins_when_both_measured_instruments_have_a_value() -> None:
    """[[hr_reserve_vo2max]] D2: the inversion is the fallback, not the other half."""
    tier = select_measured_tier(
        [_session(METHOD_RESERVE, 1, RESERVE_VALUE, 0.8), _session(METHOD_GRADED, 3, GRADED_VALUE)],
        _TODAY,
    )
    assert tier is not None
    assert tier.method == METHOD_GRADED
    assert tier.value == GRADED_VALUE


def test_precedence_is_not_recency() -> None:
    """A graded fit two weeks old still beats a reserve inversion from yesterday.

    The ranking is by what each instrument ASSUMES — the graded fit measures this person's
    own VO₂–HR line, the inversion assumes a population equivalence the largest study of
    it rejects — and that does not decay across a fortnight. Written down because "newest
    wins" is the reading someone will reach for on a first pass.
    """
    tier = select_measured_tier(
        [
            _session(METHOD_RESERVE, 0, RESERVE_VALUE, 0.8),
            _session(METHOD_GRADED, MEASURED_VO2MAX_MAX_AGE_DAYS, GRADED_VALUE),
        ],
        _TODAY,
    )
    assert tier is not None
    assert (tier.method, tier.value) == (METHOD_GRADED, GRADED_VALUE)


def test_the_two_methods_are_never_averaged() -> None:
    """D4, stated as a value: the answer is one instrument's, never anything between.

    The owner's own pair is the sharpest case there is — a blend of 39.6 and 41.7 lands on
    40.7, a tenth away from the 40.6 his Jurca fallback returns, so a blended number would
    be indistinguishable from a correctly-tiered one by inspection.
    """
    tier = select_measured_tier(
        [_session(METHOD_GRADED, 2, GRADED_VALUE), _session(METHOD_RESERVE, 1, RESERVE_VALUE, 0.9)],
        _TODAY,
    )
    assert tier is not None
    assert tier.value == GRADED_VALUE
    assert tier.value != _BLEND_OF_THE_TWO
    assert tier.n_sessions == 1, "only the winning instrument's sessions count toward it"


@pytest.mark.parametrize("order", list(permutations(range(4))))
def test_no_ordering_of_sessions_can_produce_a_value_from_two_instruments(
    order: tuple[int, ...],
) -> None:
    """Exhaustive over input order: the answer is always exactly one instrument's median.

    The no-blending guarantee has to hold however the rows arrive, so this drives every
    permutation of a mixed set and asserts the result is a member of the winning
    instrument's OWN values — not merely "not the mean", which a subtly wrong
    implementation could still satisfy by accident.
    """
    sessions = [
        _session(METHOD_GRADED, 1, 38.0),
        _session(METHOD_GRADED, 4, 42.0),
        _session(METHOD_RESERVE, 2, 30.0, 0.8),
        _session(METHOD_RESERVE, 3, 60.0, 0.8),
    ]
    tier = select_measured_tier([sessions[i] for i in order], _TODAY)
    assert tier is not None
    assert tier.method == METHOD_GRADED
    # median of the graded pair, and of nothing else. Every reserve value is outside the
    # graded pair's range, so any leakage moves this.
    assert tier.value == 40.0
    assert tier.n_sessions == 2


def test_the_median_is_across_sessions_of_one_instrument() -> None:
    """[[hr_reserve_vo2max]] D6 / [[submaximal_vo2max]] D5: the median across sessions,
    never one session as a fact — but across ONE instrument's sessions, because a median
    over mixed instruments IS D4's forbidden average whenever the count is even."""
    tier = select_measured_tier(
        [
            _session(METHOD_GRADED, 1, 36.0),
            _session(METHOD_GRADED, 2, 40.0),
            _session(METHOD_GRADED, 3, 50.0),
        ],
        _TODAY,
    )
    assert tier is not None
    assert (tier.value, tier.n_sessions) == (40.0, 3)


def test_a_single_session_still_produces_a_value_and_says_so() -> None:
    """Refusing at n = 1 would leave the measured tier inert — the owner has two
    qualifying sessions in four months. The number ships; ``n_sessions`` is what carries
    "this is one session, not a settled level" to the payload."""
    tier = select_measured_tier([_session(METHOD_GRADED, 0, GRADED_VALUE)], _TODAY)
    assert tier is not None
    assert (tier.value, tier.n_sessions) == (GRADED_VALUE, 1)


def test_the_declared_precedence_is_the_notes_order() -> None:
    assert MEASURED_PRECEDENCE == (METHOD_GRADED, METHOD_RESERVE)


# ── the freshness horizon ────────────────────────────────────────────────────


def test_a_session_exactly_at_the_horizon_still_speaks_for_today() -> None:
    """14 days is the last day a measurement is inside the drift the evidence allows
    (``derive/freshness.py``); the boundary is inclusive, as the evidence is quoted."""
    tier = select_measured_tier(
        [_session(METHOD_GRADED, MEASURED_VO2MAX_MAX_AGE_DAYS, GRADED_VALUE)], _TODAY
    )
    assert tier is not None
    assert tier.value == GRADED_VALUE


def test_a_session_one_day_past_the_horizon_does_not() -> None:
    assert (
        select_measured_tier(
            [_session(METHOD_GRADED, MEASURED_VO2MAX_MAX_AGE_DAYS + 1, GRADED_VALUE)], _TODAY
        )
        is None
    )


def test_the_owners_seven_week_old_sessions_do_not_speak_for_today() -> None:
    """The case that motivated the horizon. On 2026-08-02 his measured values were from
    2026-06-15 and 2026-06-18 — seven weeks, past the point where a break in training
    shows up in a real VO₂max (≈4–7% by 2–3 weeks, [[specificity_and_recovery]]). Holding
    them would flatter him, which is the direction #108 already cost this project years
    over. They fall through to the fallback tier rather than blanking the metric."""
    assert (
        select_measured_tier(
            [
                _session(METHOD_GRADED, 48, GRADED_VALUE),
                _session(METHOD_RESERVE, 45, RESERVE_VALUE),
            ],
            _TODAY,
        )
        is None
    )


def test_a_session_recorded_after_the_day_is_not_that_days_fitness() -> None:
    """A measurement from tomorrow is not a claim about today, however close it sits."""
    assert select_measured_tier([_session(METHOD_GRADED, -1, GRADED_VALUE)], _TODAY) is None
