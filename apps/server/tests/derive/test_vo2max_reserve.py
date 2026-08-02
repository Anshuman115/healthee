"""Known-value + gate tests for the %HRR reserve inversion (#114).

The known values are hand-computable from the published relationship, and the refusal
tests pin the finding this module exists to record: **inverting %HRR = %VO2R on ordinary
walking produces a number that is wrong, not merely uncertain, so it must never produce
one.** Every constant asserted here traces to [[hr_reserve_vo2max]]; break one and a
test below fails by design.
"""

from __future__ import annotations

import pytest

from healthee.derive.vo2max_reserve import (
    MAX_HRR,
    MIN_HRR,
    MIN_RESERVE_WINDOWS,
    MIN_SPEED_MS,
    VO2_REST_ML_KG_MIN,
    WITHHOLD_FEW_RESERVE_WINDOWS,
    WITHHOLD_HRR_TOO_LOW,
    WITHHOLD_IMPLAUSIBLE,
    WITHHOLD_NO_RESTING_HR,
    WITHHOLD_NO_STEADY_WINDOWS,
    WITHHOLD_WALKING_ONLY,
    hrr_fraction,
    reserve_vo2max,
    vo2max_from_reserve,
)
from healthee.derive.vo2max_submax import SteadyWindow

# The owner's real parameters on 2026-06-15, from the prod dump: dob 1994-06-30 (age 31),
# 7-day median rhr_daily 54.4 bpm, Tanaka HRmax 208 - 0.7*31 = 186.3.
HR_REST = 54.4
HR_MAX = 186.3
RESERVE = HR_MAX - HR_REST  # 131.9 bpm


def _win(hr: float, vo2: float, speed_ms: float = 2.6, elapsed_s: float = 300.0) -> SteadyWindow:
    """A steady window; the default speed is running pace (9.4 km/h)."""
    return SteadyWindow(hr=hr, vo2=vo2, speed_ms=speed_ms, elapsed_s=elapsed_s)


def _windows(n: int, hr: float, vo2: float, speed_ms: float = 2.6) -> list[SteadyWindow]:
    return [_win(hr, vo2, speed_ms, 300.0 + 30 * i) for i in range(n)]


# ── Known values: the arithmetic of the equivalence ──────────────────────────


def test_hrr_fraction_is_karvonen() -> None:
    """(HR - HRrest) / (HRmax - HRrest), hand-checked at the midpoint of the reserve."""
    assert hrr_fraction(HR_REST, HR_REST, HR_MAX) == pytest.approx(0.0)
    assert hrr_fraction(HR_MAX, HR_REST, HR_MAX) == pytest.approx(1.0)
    assert hrr_fraction(HR_REST + RESERVE / 2, HR_REST, HR_MAX) == pytest.approx(0.5)


def test_reserve_inversion_known_value() -> None:
    """VO2max = 3.5 + (VO2 - 3.5)/%HRR, hand-computed.

    At exactly half the reserve (HR = 54.4 + 131.9/2 = 120.35) a window costing
    21.75 mL/kg/min inverts to 3.5 + (21.75 - 3.5)/0.5 = 3.5 + 36.5 = 40.0 exactly.
    """
    got = reserve_vo2max(_win(HR_REST + RESERVE / 2, 21.75), HR_REST, HR_MAX)
    assert got == pytest.approx(40.0)


def test_reserve_inversion_is_self_consistent_at_any_hrr() -> None:
    """The identity's OWN prediction: the estimate must not depend on %HRR.

    A person with a true VO2max of 40 exercising at any admissible fraction of reserve
    must invert back to 40 from every window. This is the property the owner's WALKING
    windows measurably violate (10.6 at 75-85% reserve vs 42.3 for running at the same
    %HRR) — the reason this module refuses walking, expressed as an assertion about the
    arithmetic rather than about the data.
    """
    true_vo2max = 40.0
    for hrr in (0.35, 0.5, 0.65, 0.8, 0.95):
        vo2 = VO2_REST_ML_KG_MIN + hrr * (true_vo2max - VO2_REST_ML_KG_MIN)
        window = _win(HR_REST + hrr * RESERVE, vo2)
        assert reserve_vo2max(window, HR_REST, HR_MAX) == pytest.approx(true_vo2max)


def test_vo2rest_is_the_met_convention() -> None:
    """3.5 mL/kg/min — the same resting term the ACSM equations carry (Byrne 2005 shows
    it is ~35% high; the note documents why we keep it anyway)."""
    assert VO2_REST_ML_KG_MIN == 3.5


def test_validated_hrr_range_is_lounana_2007() -> None:
    """35-95% of reserve — Lounana 2007's stated range, NOT a value tuned to our data.

    This test OWNS the two values. The boundary tests below are deliberately written
    relative to the constants, because what they assert is the RULE (inclusive at both
    ends, refuse outside) and that rule is true whatever the sourced numbers are. That
    split only works while exactly one test pins the literals, so if this assertion is
    ever relaxed the constants become unguarded — a mutation run showed the boundary
    tests alone stay green when the range is widened.
    """
    assert (MIN_HRR, MAX_HRR) == (0.35, 0.95)


# ── The %HRR window: refuse outside the validated range ──────────────────────


def test_window_below_the_floor_is_refused() -> None:
    just_under = HR_REST + (MIN_HRR - 0.01) * RESERVE
    assert reserve_vo2max(_win(just_under, 12.0), HR_REST, HR_MAX) is None


def test_window_at_the_floor_is_admitted() -> None:
    """The bound is inclusive, matching how the source states it ("35-95%HRR range")."""
    at_floor = HR_REST + MIN_HRR * RESERVE
    assert reserve_vo2max(_win(at_floor, 12.0), HR_REST, HR_MAX) is not None


def test_window_above_the_ceiling_is_refused() -> None:
    over = HR_REST + (MAX_HRR + 0.01) * RESERVE
    assert reserve_vo2max(_win(over, 40.0), HR_REST, HR_MAX) is None


# ── Session gates: fail closed, and name the reason ──────────────────────────


def test_walking_session_withholds_and_says_so() -> None:
    """THE test this task exists for.

    Thirty steady windows of brisk walking at 5.8 km/h with a heart rate two-thirds of
    the way up the reserve — the owner's real 2026-06-12/13/16 profile. It must produce
    NO number. Left ungated it returns ~21 mL/kg/min for a man whose own data floors him
    near 39, so a caveat is not an acceptable substitute for a refusal.
    """
    walking = _windows(30, hr=HR_REST + 0.55 * RESERVE, vo2=13.2, speed_ms=1.6)
    result, reason = vo2max_from_reserve(walking, HR_REST, HR_MAX)
    assert result is None
    assert reason == WITHHOLD_WALKING_ONLY


def test_walking_would_have_produced_a_wrong_number(recwarn: pytest.WarningsRecorder) -> None:  # noqa: ARG001
    """Prove the gate is load-bearing, not decorative.

    The same walking windows, inverted directly, land far below the floor the owner's
    own sustained VO2 sets (38.9 mL/kg/min held at 169 bpm on 2026-06-15). This is the
    number the walking gate is stopping from being published.
    """
    walking = _win(HR_REST + 0.55 * RESERVE, 13.2, speed_ms=1.6)
    ungated = reserve_vo2max(walking, HR_REST, HR_MAX)
    assert ungated is not None
    assert ungated < 25.0  # vs a true value corroborated at 39.6-41.7
    assert ungated < 38.9  # refuted by his own sustained submaximal VO2


def test_running_session_produces_a_number() -> None:
    """The owner's real 2026-06-15 running profile: ~9.3 km/h at 86% of reserve."""
    running = _windows(7, hr=HR_REST + 0.865 * RESERVE, vo2=35.2, speed_ms=2.58)
    result, reason = vo2max_from_reserve(running, HR_REST, HR_MAX)
    assert reason == "ok"
    assert result is not None
    assert result.vo2max == pytest.approx(40.1, abs=0.1)
    assert result.n_windows == 7
    assert result.hrr_median == pytest.approx(0.865, abs=0.001)


def test_too_few_running_windows_withholds() -> None:
    """Five steady half-minutes is not a session.

    The count is spelled out as a LITERAL 5/6 rather than as ``MIN_RESERVE_WINDOWS - 1``.
    Deriving the fixture from the constant makes the test move with it, so lowering the
    gate would silently keep this green — a mutation run caught exactly that.
    """
    assert MIN_RESERVE_WINDOWS == 6  # matches vo2max_submax.MIN_WINDOWS
    result, reason = vo2max_from_reserve(
        _windows(5, hr=HR_REST + 0.865 * RESERVE, vo2=35.2), HR_REST, HR_MAX
    )
    assert result is None
    assert reason == WITHHOLD_FEW_RESERVE_WINDOWS

    six, _ = vo2max_from_reserve(
        _windows(6, hr=HR_REST + 0.865 * RESERVE, vo2=35.2), HR_REST, HR_MAX
    )
    assert six is not None  # ...and six IS enough, so the boundary is pinned both ways


def test_running_but_outside_the_validated_hrr_range_withholds() -> None:
    """Fast enough, but every window sits under the 35% floor — refuse, don't divide."""
    running = _windows(12, hr=HR_REST + 0.30 * RESERVE, vo2=35.2)
    result, reason = vo2max_from_reserve(running, HR_REST, HR_MAX)
    assert result is None
    assert reason == WITHHOLD_HRR_TOO_LOW


def test_no_windows_at_all_withholds() -> None:
    for windows in ([], None):
        result, reason = vo2max_from_reserve(windows, HR_REST, HR_MAX)
        assert result is None
        assert reason == WITHHOLD_NO_STEADY_WINDOWS


def test_missing_resting_hr_withholds() -> None:
    running = _windows(12, hr=HR_REST + 0.865 * RESERVE, vo2=35.2)
    result, reason = vo2max_from_reserve(running, None, HR_MAX)
    assert result is None
    assert reason == WITHHOLD_NO_RESTING_HR


def test_degenerate_reserve_span_withholds() -> None:
    """A resting HR within 40 bpm of the predicted maximum is not a reserve."""
    running = _windows(12, hr=170.0, vo2=35.2)
    result, reason = vo2max_from_reserve(running, 160.0, HR_MAX)
    assert result is None
    assert reason == WITHHOLD_NO_RESTING_HR


def test_implausible_result_withholds() -> None:
    """A cost that inverts above the human ceiling is refused, not clamped."""
    running = _windows(12, hr=HR_REST + 0.40 * RESERVE, vo2=38.0)
    result, reason = vo2max_from_reserve(running, HR_REST, HR_MAX)
    assert result is None
    assert reason == WITHHOLD_IMPLAUSIBLE


# ── Aggregation: the median, and why it has to be ────────────────────────────


def test_one_wild_window_does_not_move_the_answer() -> None:
    """A single window whose DEM grade or interpolated HR is momentarily wrong must not
    move the session. The owner's real 06-13 track has a window reading 42.7 against a
    session median of 22.1; the mean would chase it, the median does not."""
    hr = HR_REST + 0.865 * RESERVE
    windows = _windows(8, hr=hr, vo2=35.2)
    clean, _ = vo2max_from_reserve(windows, HR_REST, HR_MAX)
    windows[3] = _win(hr, 70.0)  # one absurd window
    polluted, _ = vo2max_from_reserve(windows, HR_REST, HR_MAX)
    assert clean is not None and polluted is not None
    assert polluted.vo2max == pytest.approx(clean.vo2max)


def test_walking_windows_are_dropped_from_a_mixed_session() -> None:
    """2026-06-18 is run/walk intervals. The walking windows between the runs are
    recovery, not steady load, and must not enter the median."""
    running = _windows(8, hr=HR_REST + 0.865 * RESERVE, vo2=35.2, speed_ms=2.58)
    walking = _windows(20, hr=HR_REST + 0.75 * RESERVE, vo2=13.0, speed_ms=1.6)
    result, reason = vo2max_from_reserve(running + walking, HR_REST, HR_MAX)
    assert reason == "ok"
    assert result is not None
    assert result.n_windows == 8  # the 20 walking windows are gone
    assert result.vo2max > 38.0


def test_min_speed_is_the_acsm_equation_switch() -> None:
    """The running gate reuses the existing ACSM walk/run boundary rather than adding a
    second, differently-valued threshold for the same physical question."""
    from healthee.derive.vo2max_submax import RUN_SPEED_MS

    assert MIN_SPEED_MS == RUN_SPEED_MS
