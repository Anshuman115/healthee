"""Known-value tests for the time predicate — the reader, the clock, and the crux.

Three things are pinned here and each has its own way of going quietly wrong:

1. **The window resolves in the OWNER's clock.** One set of instants is read through
   three zones and produces three different answers, all hand-computed. This repo has
   shipped two live wrong numbers from calendar-date-vs-instant confusion, and a window
   is that bug class with an extra dimension — it can put a coffee on the wrong DAY *and*
   on the wrong side of the cutoff.
2. **The boundary.** An entry at exactly HH:00 is INSIDE the window, which is the same
   boundary ``analytics.cutoffs`` classifies its nights by. If the two disagreed, a
   challenge could score a coffee the finding that motivated it did not count.
3. **Zero is not unlogged.** A day the owner logged something and drank nothing late is a
   real ``0.0``; a day they logged nothing at all is ABSENT. The contrast against the
   daily-total metric — which zero-fills the same days — is asserted directly, because
   the difference between the two readers is the whole honesty argument.

The zones are chosen so the expected numbers cannot rot: Asia/Kolkata (+5:30) and
Pacific/Honolulu (-10:00) have had no DST for the better part of a century, so a tz-db
update cannot move them. Every date is fixed, never "N days ago".

Auto-skips without a reachable TimescaleDB.
"""

from __future__ import annotations

from collections.abc import Iterator, Sequence
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges.evaluate import evaluate_challenge
from healthee.challenges.series import metric_series, recent_window
from healthee.core.db import tenant_transaction
from healthee.db import migrate

pytestmark = pytest.mark.integration

# Three DST-free zones: positive offset, zero, negative offset.
IST = "Asia/Kolkata"  # +05:30, no DST since 1945
UTC_TZ = "UTC"
HST = "Pacific/Honolulu"  # -10:00, no DST since 1947

_DAY = date(2026, 3, 2)
_NEXT = date(2026, 3, 3)
_PREV = date(2026, 3, 1)

# One set of instants, read through three clocks.
#   02:00Z  ->  IST 07:30 (03-02) · UTC 02:00 (03-02) · HST 16:00 (03-01)
#   11:00Z  ->  IST 16:30 (03-02) · UTC 11:00 (03-02) · HST 01:00 (03-02)
#   17:30Z  ->  IST 23:00 (03-02) · UTC 17:30 (03-02) · HST 07:30 (03-02)
_ENTRIES = [
    (datetime(2026, 3, 2, 2, 0, tzinfo=UTC), 80.0, "mg"),
    (datetime(2026, 3, 2, 11, 0, tzinfo=UTC), 100.0, "mg"),
    (datetime(2026, 3, 2, 17, 30, tzinfo=UTC), 120.0, "mg"),
]


@pytest.fixture
def clean_db(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _series(metric: str, tz: str, since: date, until: date) -> dict[date, float]:
    with tenant_transaction(_seed.OWNER) as cur:
        return metric_series(cur, _seed.OWNER, tz, metric, since, until=until)


def _seed_entries(entries: Sequence[tuple[datetime, float, str | None]]) -> None:
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(cur, _seed.OWNER, "caffeine", entries)


# ── 1. the window resolves in the OWNER's clock ───────────────────────────────


def test_one_set_of_instants_reads_differently_in_each_owners_clock(
    clean_db: None,  # noqa: ARG001
) -> None:
    """The same three coffees, three zones, three hand-computed answers.

    IST puts two of them past 16:00 (16:30 and 23:00); UTC puts one there (17:30);
    Honolulu puts the earliest one past 16:00 on the PREVIOUS day and leaves 03-02 clean.
    A window read in the server's zone would give one answer for all three owners.
    """
    _seed_entries(_ENTRIES)

    assert _series("caffeine_after_16", IST, _PREV, _NEXT) == {_DAY: 220.0}
    assert _series("caffeine_after_16", UTC_TZ, _PREV, _NEXT) == {_DAY: 120.0}
    assert _series("caffeine_after_16", HST, _PREV, _NEXT) == {_PREV: 80.0, _DAY: 0.0}


def test_a_later_window_is_a_strict_subset_of_an_earlier_one(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Nested windows must nest. ``after_20`` can never exceed ``after_12`` on a day."""
    _seed_entries(_ENTRIES)

    assert _series("caffeine_after_12", IST, _PREV, _NEXT) == {_DAY: 220.0}
    assert _series("caffeine_after_20", IST, _PREV, _NEXT) == {_DAY: 120.0}
    assert _series("caffeine_after_22", IST, _PREV, _NEXT) == {_DAY: 120.0}


def test_the_daily_total_is_the_same_number_in_every_zone(
    clean_db: None,  # noqa: ARG001
) -> None:
    """A control: only the WINDOW is zone-sensitive here, not the amounts.

    All three entries land on 03-02 in IST and UTC, so the day's total is 300 in both;
    Honolulu splits them across two days. That is the day bucketing all metrics already
    have — the extra thing the window adds is which side of the clock each entry falls on.
    """
    _seed_entries(_ENTRIES)

    assert _series("caffeine_after_12", UTC_TZ, _PREV, _NEXT)[_DAY] == 120.0  # 11:00 excluded
    assert sum(_series("caffeine_mg", IST, _PREV, _NEXT).values()) == 300.0
    assert sum(_series("caffeine_mg", HST, _PREV, _NEXT).values()) == 300.0


# ── 2. the boundary ───────────────────────────────────────────────────────────


def test_an_entry_at_exactly_the_cutoff_hour_is_inside_the_window(
    clean_db: None,  # noqa: ARG001
) -> None:
    """``>=``, the same boundary ``analytics.cutoffs`` draws.

    16:00:00 counts toward ``after_16`` and 15:59:59 does not. If this flipped, a
    challenge would score a coffee the personal finding it came from did not count — the
    two would be measuring different behaviours under one name.
    """
    _seed_entries(
        [
            (datetime(2026, 3, 2, 15, 59, 59, tzinfo=UTC), 40.0, "mg"),
            (datetime(2026, 3, 2, 16, 0, 0, tzinfo=UTC), 60.0, "mg"),
        ]
    )

    assert _series("caffeine_after_16", UTC_TZ, _PREV, _NEXT) == {_DAY: 60.0}
    assert _series("caffeine_after_12", UTC_TZ, _PREV, _NEXT) == {_DAY: 100.0}
    assert _series("caffeine_after_18", UTC_TZ, _PREV, _NEXT) == {_DAY: 0.0}


def test_the_boundary_is_the_owners_clock_not_the_servers(
    clean_db: None,  # noqa: ARG001
) -> None:
    """The same instant is inside the window for one owner and outside it for another."""
    _seed_entries([(datetime(2026, 3, 2, 11, 0, tzinfo=UTC), 90.0, "mg")])

    assert _series("caffeine_after_16", IST, _PREV, _NEXT) == {_DAY: 90.0}  # 16:30 local
    assert _series("caffeine_after_16", UTC_TZ, _PREV, _NEXT) == {_DAY: 0.0}  # 11:00 local


# ── 3. zero is not unlogged — the honesty crux ────────────────────────────────


def test_a_logged_day_with_nothing_late_is_a_real_zero(
    clean_db: None,  # noqa: ARG001
) -> None:
    """They logged, and none of it was late: that is evidence of a clean evening."""
    _seed_entries([(datetime(2026, 3, 2, 6, 0, tzinfo=UTC), 150.0, "mg")])

    assert _series("caffeine_after_16", UTC_TZ, _PREV, _NEXT) == {_DAY: 0.0}


def test_a_day_with_no_log_at_all_is_absent_and_never_a_zero(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Silence may not read as compliance — the whole reason this reader exists.

    The daily TOTAL zero-fills the identical window (``ManualEntrySource`` argues why it
    may), so the contrast is asserted side by side: the same three days give the window a
    two-day series and the total a three-day one. If the window ever starts zero-filling,
    this is the test that says what was lost.
    """
    _seed_entries(
        [
            (datetime(2026, 3, 1, 20, 0, tzinfo=UTC), 100.0, "mg"),
            (datetime(2026, 3, 3, 8, 0, tzinfo=UTC), 50.0, "mg"),
        ]
    )

    windowed = _series("caffeine_after_16", UTC_TZ, _PREV, _NEXT)
    total = _series("caffeine_mg", UTC_TZ, _PREV, _NEXT)

    assert windowed == {_PREV: 100.0, _NEXT: 0.0}
    assert _DAY not in windowed, "an unlogged day must not appear at all"
    assert total == {_PREV: 100.0, _DAY: 0.0, _NEXT: 50.0}


def test_a_baseline_counts_only_the_days_it_actually_measured(
    clean_db: None,  # noqa: ARG001
) -> None:
    """The day count is what makes ``bounds`` refuse to calibrate on silence.

    Three logged days out of the trailing seven is below ``MIN_COMPARISON_DAYS``, so the
    same estimator that produces the baseline also reports the number that gets the metric
    marked UNAVAILABLE. The alternative — zero-filling to seven days and reporting a
    confident low average — is exactly the optimistic guess this product refuses.
    """
    ref = date(2026, 3, 8)
    _seed_entries([(datetime(2026, 3, i, 19, 0, tzinfo=UTC), 90.0, "mg") for i in (3, 5, 7)])

    with tenant_transaction(_seed.OWNER) as cur:
        windowed = recent_window(cur, _seed.OWNER, UTC_TZ, "caffeine_after_16", "daily", ref)
        total = recent_window(cur, _seed.OWNER, UTC_TZ, "caffeine_mg", "daily", ref)

    assert windowed == (90.0, 3)  # mean of the three days it saw
    assert total == (38.6, 7)  # 270/7, on seven zero-filled days


# ── the evaluation, end to end ────────────────────────────────────────────────

_ADOPTED = datetime(2026, 3, 1, 6, 0, tzinfo=UTC)


def _cap(metric: str) -> dict:
    return {
        "metric": metric,
        "comparator": "<=",
        "target_value": 100.0,
        "cadence": "daily",
        "window_days": 5,
        "adopted_at": _ADOPTED,
        "baseline_value": 200.0,
    }


def test_a_windowed_cap_scores_only_the_days_it_can_see(
    clean_db: None,  # noqa: ARG001
) -> None:
    """Hand-computed. Five days: clean, blown, UNLOGGED, clean, clean.

    * hits are days 1, 4, 5 ⇒ progress 3/5 = 0.6, not complete;
    * the streak walks back from day 5 through day 4 and STOPS at the unlogged day —
      which is neither a hit nor protected, so it breaks the run at 2.

    The daily TOTAL reading the same five days materialises 03-03 as 0 mg and scores it as
    a hit. That is the silent-compliance failure, shown side by side: on the window the
    unlogged day earns nothing, on the total it earns a pass.
    """
    unlogged = date(2026, 3, 3)
    _seed_entries(
        [
            (datetime(2026, 3, 1, 8, 0, tzinfo=UTC), 150.0, "mg"),  # logged, nothing late
            (datetime(2026, 3, 2, 20, 0, tzinfo=UTC), 120.0, "mg"),  # blown
            # 2026-03-03: nothing logged at all
            (datetime(2026, 3, 4, 19, 0, tzinfo=UTC), 50.0, "mg"),  # under the cap
            (datetime(2026, 3, 5, 7, 0, tzinfo=UTC), 200.0, "mg"),  # logged, nothing late
        ]
    )
    today = date(2026, 3, 5)

    with tenant_transaction(_seed.OWNER) as cur:
        windowed = evaluate_challenge(
            cur, _seed.OWNER, UTC_TZ, _cap("caffeine_after_16"), today=today
        )
        total = evaluate_challenge(cur, _seed.OWNER, UTC_TZ, _cap("caffeine_mg"), today=today)

    assert (windowed["hit_days"], windowed["progress"], windowed["complete"]) == (3, 0.6, False)
    assert windowed["streak"] == 2
    assert windowed["today_value"] == 0.0
    assert windowed["today_hit"] is True
    # The unlogged day: absent from the window, a scored zero on the total.
    assert unlogged not in _series("caffeine_after_16", UTC_TZ, _PREV, today)
    assert _series("caffeine_mg", UTC_TZ, _PREV, today)[unlogged] == 0.0
    assert total["streak"] == 0, "the total's day-5 200 mg breaks its run; the window's 0 does not"


def test_an_owner_who_stops_logging_scores_nothing_rather_than_everything(
    clean_db: None,  # noqa: ARG001
) -> None:
    """The failure mode the whole design is aimed at, asserted as a number.

    A cap satisfied by absence would hand a perfect week to somebody who simply stopped
    logging. Here the window sees no days at all, so it awards no hits — "we did not see
    that" rather than "you were clean".
    """
    today = date(2026, 3, 5)
    with tenant_transaction(_seed.OWNER) as cur:
        progress = evaluate_challenge(
            cur, _seed.OWNER, UTC_TZ, _cap("caffeine_after_16"), today=today
        )

    assert (progress["hit_days"], progress["progress"], progress["streak"]) == (0, 0.0, 0)
    assert progress["complete"] is False
    assert progress["today_value"] is None


def test_the_window_is_daily_only_and_says_so_rather_than_summing_silence(
    clean_db: None,  # noqa: ARG001
) -> None:
    """A weekly window is UNREPRESENTABLE, the same way a weekly ``sri`` is (#67).

    A period total cannot distinguish an unmeasured day from a zero one, so seven days of
    silence would sum to 0 and report the cap kept. Refused at the vocabulary rather than
    scored wrong.
    """
    _seed_entries(_ENTRIES)
    weekly = _cap("caffeine_after_16") | {"cadence": "weekly"}

    with tenant_transaction(_seed.OWNER) as cur, pytest.raises(ValueError, match="cannot be"):
        evaluate_challenge(cur, _seed.OWNER, UTC_TZ, weekly, today=date(2026, 3, 5))


def test_the_unit_rule_is_the_one_the_daily_total_already_used(
    clean_db: None,  # noqa: ARG001
) -> None:
    """A row in another unit is skipped, not converted — "2 cups" is not milligrams.

    Inherited rather than restated: the window's source carries the base metric's unit, so
    there is one answer to "which rows count" for caffeine however it is sliced.
    """
    _seed_entries(
        [
            (datetime(2026, 3, 2, 20, 0, tzinfo=UTC), 90.0, "mg"),
            (datetime(2026, 3, 2, 21, 0, tzinfo=UTC), 2.0, "cups"),
            (datetime(2026, 3, 2, 22, 0, tzinfo=UTC), 30.0, None),  # the client's default IS mg
        ]
    )

    assert _series("caffeine_after_16", UTC_TZ, _PREV, _NEXT) == {_DAY: 120.0}


def test_the_lead_in_day_evaluate_reads_cannot_invent_a_hit(
    clean_db: None,  # noqa: ARG001
) -> None:
    """``evaluate`` reads one day before the start; that day must not become a hit.

    A zero-filling reader would materialise the lead-in day as 0 mg. It is outside the
    scored range either way, and this pins that the window does not create the row at all.
    """
    _seed_entries([(datetime(2026, 3, 4, 19, 0, tzinfo=UTC), 50.0, "mg")])

    series = _series("caffeine_after_16", UTC_TZ, _PREV - timedelta(days=1), date(2026, 3, 5))

    assert series == {date(2026, 3, 4): 50.0}
