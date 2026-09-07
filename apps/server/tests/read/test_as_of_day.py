"""An answer for day D contains nothing measured, computed or observed after D.

``docs/AS_OF_DAY.md`` section 3 names this the FUTURE LEAK and calls it the mirror of
the stale-as-current failure ``derive/freshness.py`` exists for: one shows new data
under an old date, the other shows old judgements under a new one. Both are the app
claiming to know something it did not.

The trap is that "latest" is everywhere, and every one of those reads is CORRECT on the
current day — which is why a suite that only exercised today would pass against a read
layer with no day bound at all. So every test here seeds a value AFTER the day it asks
about, at a number the reference day could not possibly have known, and then asserts the
answer is the earlier one. A leak surfaces as the wrong number, not as a missing key.

Four properties, each of which is also a mutation in the report:

1. **No value dated after D reaches D's answer** — the leak itself.
2. **A freshness horizon is measured from D, not from today** — a weight three days
   old on 29 July WAS that owner's weight on 29 July, and a horizon anchored to the
   wall clock would call it six weeks stale and withhold a number we hold.
3. **A day with no row withholds rather than borrowing its neighbour's** — in the
   existing ``Reading`` vocabulary, with the older value surviving only INSIDE the
   ``withheld`` block where nothing can mistake it for the day's own.
4. **The payload names the day it answers for**, so the client cannot mislabel it.

The seeded day is deliberately far back (``_DAYS_AGO``), so "bounded by D" and "bounded
by today" give visibly different answers — a day one behind today would let a wall-clock
anchor pass most of these by luck.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.read.common import day_derived_at, latest_derived
from healthee.read.findings import top_findings
from healthee.read.health_metrics import illness_flag_payload
from healthee.read.today import today_snapshot
from healthee.read.today_series import hr_hourly, secondary_cards
from healthee.read.vo2max import vo2max_payload

pytestmark = pytest.mark.integration

# How far back the day under test sits. Bigger than every horizon in the read layer
# (the 14-day weight and measured-fitness horizons, the 30-day baselines), so an answer
# anchored to the wall clock cannot accidentally agree with one anchored to the day.
_DAYS_AGO = 40

# The value filed under the day, and the value filed AFTER it. Far apart and both
# physiologically plausible, so a leak reads as the wrong number rather than as an
# absurd one a rounding bug could also explain.
_ON_DAY = 40.0
_AFTER_DAY = 55.0

_STEPS_ON_DAY = 6100.0
_STEPS_AFTER_DAY = 19400.0


def _as_of() -> date:
    """The day every test here asks about — a real past day in the owner's calendar."""
    return user_today(SENTINEL_TZ) - timedelta(days=_DAYS_AGO)


def _reset(cur) -> None:
    for table in ("derived_daily", "weight_log", "profile", "finding", "illness_flag"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def _daily(cur, day: date, metric: str, value: float, flags: str = "{}") -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, %s, %s, %s::jsonb) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value, "
        "  flags = EXCLUDED.flags",
        (SENTINEL_USER_ID, day, metric, value, flags),
    )


@pytest.fixture
def bed(db: None):  # noqa: ARG001 — gates on DB reachability
    """A clean owner with a profile, inside one tenant transaction per test."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        cur.execute(
            "INSERT INTO profile (user_id, height_cm, sex, dob, srpa) "
            "VALUES (%s, 175, 'male', '1990-01-01', 0)",
            (SENTINEL_USER_ID,),
        )
        yield cur
        _reset(cur)


# ── 1. the future leak ───────────────────────────────────────────────────────


def test_a_vo2max_answer_never_takes_an_estimate_dated_after_the_day(bed) -> None:
    """The "latest" ``docs/AS_OF_DAY.md`` names first, at the value level.

    Both rows are real ``vo2max_estimate`` rows and the later one is NEWER, so the
    unbounded read returns it. With the window closed at the day, ``rows[-1]`` is the
    day's own row and the estimate IS that day's number — a leak would blank the
    estimate instead (the later row is not the reference day's, so the freshness gate
    would withhold), which is why this asserts a value and not merely a date.
    """
    _daily(bed, _as_of(), "vo2max_estimate", _ON_DAY)
    _daily(bed, _as_of() + timedelta(days=5), "vo2max_estimate", _AFTER_DAY)

    payload = vo2max_payload(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())

    assert payload is not None
    assert payload["estimate"] == _ON_DAY, "the answer took a value dated after the day"
    assert payload["as_of_date"] == _as_of().isoformat()
    assert payload["withheld"] is None


def test_a_trend_stops_at_the_day_it_answers_for(bed) -> None:
    """A 90-day trend that ran past the day would draw a line into the owner's future."""
    _daily(bed, _as_of(), "vo2max_estimate", _ON_DAY)
    _daily(bed, _as_of() + timedelta(days=5), "vo2max_estimate", _AFTER_DAY)

    payload = vo2max_payload(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())

    assert payload is not None
    dates = [point["date"] for point in payload["trend_90d"]]
    assert dates, "the trend must not be empty — that would pass this test vacuously"
    assert max(dates) <= _as_of().isoformat(), f"trend runs past the day: {max(dates)}"
    assert _AFTER_DAY not in [point["value"] for point in payload["trend_90d"]]


def test_a_metric_card_never_shows_a_later_days_value(bed) -> None:
    """``latest_derived`` is the shared primitive every card and signal reads through."""
    _daily(bed, _as_of(), "steps_total", _STEPS_ON_DAY)
    _daily(bed, _as_of() + timedelta(days=1), "steps_total", _STEPS_AFTER_DAY)

    row = latest_derived(bed, SENTINEL_USER_ID, "steps_total", _as_of())
    cards = secondary_cards(bed, SENTINEL_USER_ID, SENTINEL_TZ, None, _as_of())

    assert row is not None and row[1] == _STEPS_ON_DAY
    steps = next(c for c in cards if c["metric"] == "steps_total")
    assert steps["value"] == _STEPS_ON_DAY, "tomorrow's steps were served as this day's"


def test_a_baseline_is_computed_only_over_days_that_had_happened(bed) -> None:
    """The z-score prices the day's value; a window open at the top prices it against
    days the owner had not lived yet, which is the leak wearing a statistic."""
    for back in range(30):
        _daily(bed, _as_of() - timedelta(days=back), "steps_total", _STEPS_ON_DAY)
    for ahead in range(1, 15):
        _daily(bed, _as_of() + timedelta(days=ahead), "steps_total", _STEPS_AFTER_DAY)

    cards = secondary_cards(bed, SENTINEL_USER_ID, SENTINEL_TZ, None, _as_of())

    steps = next(c for c in cards if c["metric"] == "steps_total")
    assert steps["median_30d"] == _STEPS_ON_DAY, (
        f"the baseline median is {steps['median_30d']} — later days entered the window"
    )


def test_an_illness_flag_raised_after_the_day_does_not_flag_it(bed) -> None:
    """ "Active" is a two-day span AROUND the day, so the window needs both ends."""
    bed.execute(
        "INSERT INTO illness_flag "
        "  (user_id, date, severity, rr_delta_bpm, sustained, research_note_ids) "
        "VALUES (%s, %s, 'high', 2.0, TRUE, ARRAY['respiratory_rate_normal'])",
        (SENTINEL_USER_ID, _as_of() + timedelta(days=1)),
    )

    assert illness_flag_payload(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of()) is None


def test_a_finding_does_not_appear_on_a_day_before_it_was_discovered(bed) -> None:
    """``docs/AS_OF_DAY.md``: a finding must not appear on a day before it existed.

    ``computed_at`` is the only record of when we knew, so it is what bounds the read.
    """
    bed.execute(
        "INSERT INTO finding (user_id, computed_at, kind, description, metric_a, "
        "  effect_size, effect_metric, p_value, n_samples, significant) "
        "VALUES (%s, now(), 'pairwise_lag', 'DISCOVERED TODAY', 'rhr_daily', "
        "  0.5, 'spearman_r', 0.01, 40, TRUE)",
        (SENTINEL_USER_ID,),
    )

    on_day = top_findings(bed, SENTINEL_USER_ID, SENTINEL_TZ, day=_as_of())
    now = top_findings(bed, SENTINEL_USER_ID, SENTINEL_TZ)

    assert on_day == [], "a finding discovered today was shown on a day 40 days back"
    assert [f["description_raw"] for f in now] == ["DISCOVERED TODAY"], (
        "the finding must still be served for today — otherwise the bound is just a mute"
    )


# ── 2. the horizon is measured from the day ──────────────────────────────────


def test_a_weight_three_days_old_on_the_day_is_that_days_weight(bed) -> None:
    """The horizon-from-D rule, on the metric that has one.

    ``freshness.WEIGHT_MAX_AGE_DAYS`` is 14 days from the day being computed. This
    weigh-in is 3 days before the reference day and 43 days before today, so the two
    anchors disagree: from the day it is current and must be SERVED, from the wall clock
    it is stale and would be withheld. Serving it is correct — it measurably was this
    person's mass on that day ([[weight_bmi_body_composition]]).
    """
    logged_on = _as_of() - timedelta(days=3)
    bed.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, 72)",
        (SENTINEL_USER_ID, datetime.combine(logged_on, time(6), tzinfo=UTC)),
    )

    cards = secondary_cards(bed, SENTINEL_USER_ID, SENTINEL_TZ, None, _as_of())

    weight = next(c for c in cards if c["metric"] == "weight_kg")
    assert weight["value"] == pytest.approx(72.0), (
        "the horizon was measured from today — a weight that was 3 days old on the day "
        "being answered for was withheld as 43 days stale"
    )
    assert weight["withheld"] is None
    assert weight["as_of_date"] == logged_on.isoformat()


def test_a_weight_logged_after_the_day_is_not_that_days_weight(bed) -> None:
    """The other side of the same rule: a later weigh-in is not evidence about the day."""
    bed.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, 99)",
        (SENTINEL_USER_ID, datetime.combine(_as_of() + timedelta(days=1), time(6), tzinfo=UTC)),
    )

    cards = secondary_cards(bed, SENTINEL_USER_ID, SENTINEL_TZ, None, _as_of())

    assert not [c for c in cards if c["metric"] == "weight_kg"], (
        "a weigh-in from after the day was served as that day's weight"
    )


# ── 3. a day with no row withholds, and never borrows its neighbour's ────────


def test_a_day_with_no_estimate_withholds_rather_than_showing_the_day_befores(bed) -> None:
    """Rule 4: no dash, no neighbour's value, no interpolation, no default, no zero.

    The older number survives only INSIDE ``withheld``, dated and aged, which is the
    contract ``derive/freshness.py`` fixed: the current-looking field is null whenever
    the block is present.
    """
    _daily(bed, _as_of() - timedelta(days=1), "vo2max_estimate", _ON_DAY)

    payload = vo2max_payload(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())

    assert payload is not None
    assert payload["estimate"] is None, "the day borrowed the day before's estimate"
    assert payload["as_of_date"] is None
    assert payload["data_confidence"] == "insufficient_data"
    assert payload["withheld"]["last_estimate"] == _ON_DAY
    assert payload["withheld"]["last_as_of_date"] == (_as_of() - timedelta(days=1)).isoformat()
    assert payload["withheld"]["age_days"] == 1


def test_a_day_with_no_derived_rows_reports_no_computation_time(bed) -> None:
    """``derived_at`` is null for a day nothing was computed for — never a neighbour's."""
    _daily(bed, _as_of() - timedelta(days=1), "rhr_daily", 55.0)

    assert day_derived_at(bed, SENTINEL_USER_ID, _as_of()) is None
    assert day_derived_at(bed, SENTINEL_USER_ID, _as_of() - timedelta(days=1)) is not None


def test_a_day_with_no_samples_draws_an_empty_trace_not_the_neighbours(bed) -> None:
    """The intraday traces are per-day reads; an empty day is empty, not yesterday."""
    bed.execute(
        "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, 'hr', 62) "
        "ON CONFLICT (user_id, metric, ts) DO NOTHING",
        (SENTINEL_USER_ID, datetime.combine(_as_of() - timedelta(days=1), time(9), tzinfo=UTC)),
    )

    assert hr_hourly(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of()) == []
    assert hr_hourly(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of() - timedelta(days=1)) != []


# ── 4. the payload names the day, and says what it cannot answer ─────────────


def test_the_payload_names_the_day_it_answers_for(bed) -> None:
    """Rule 5. Without this the client has only its own clock to date the answer with,
    which is the wall-clock bug ``core/tenancy.py`` exists to prevent."""
    _daily(bed, _as_of(), "rhr_daily", 55.0)

    payload = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())

    assert payload["date"] == _as_of().isoformat()
    assert payload["as_of"]["day"] == _as_of().isoformat()
    assert payload["as_of"]["is_today"] is False
    assert payload["as_of"]["derived_at"] is not None


def test_todays_answer_still_says_it_is_today(bed) -> None:
    """The default path is unchanged, and it is the half a leak test cannot see."""
    _daily(bed, user_today(SENTINEL_TZ), "rhr_daily", 55.0)

    payload = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload["date"] == user_today(SENTINEL_TZ).isoformat()
    assert payload["as_of"]["is_today"] is True


def test_a_past_day_carries_no_live_feed_trust_card(bed) -> None:
    """``data_health`` is measured against the request instant, so it is an observation
    made AFTER a past day. Null is the honest answer; the app draws nothing for it."""
    _daily(bed, _as_of(), "rhr_daily", 55.0)

    past = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())
    today = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ)

    assert past["data_health"] is None
    assert today["data_health"] is not None, "the live day must still get its trust card"


def test_a_past_day_carries_no_open_fast(bed) -> None:
    """Nothing records WHEN a fast's ``end_ts`` became null, and its elapsed is measured
    from now — so neither half survives a move backwards. Withheld, not reconstructed."""
    bed.execute(
        "INSERT INTO manual_entry (user_id, ts, kind) VALUES (%s, now() - interval '2 hours', "
        "'fasting')",
        (SENTINEL_USER_ID,),
    )

    past = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ, _as_of())
    today = today_snapshot(bed, SENTINEL_USER_ID, SENTINEL_TZ)

    assert past["routine"]["open_fast"] is None
    assert today["routine"]["open_fast"] is not None, "the live day must still see the fast"
