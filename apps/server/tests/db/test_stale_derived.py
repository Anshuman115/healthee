"""The repair path can now actually repair — and cannot repair anything it was not aimed at.

Two halves, and the second one is the dangerous half:

* a re-derive leaves the derived layer matching what TODAY's code produces, **including
  the absence of rows today's code declines to write** (#118 — 109 wrong
  ``vo2max_estimate`` rows survived the fix, the deploy and the documented repair);
* a tool that can delete from ``derived_daily`` is a worse hazard than the bug it was
  written for, so every bound it claims is asserted here: owner, metric, window, and
  "nothing goes without being asked for".

The scoping and the "does not fire unless asked" assertions are the ones whose failure is
catastrophic and silent, so each is MUTATION-TESTED — the reason `test_the_owner_bound_is
_the_predicate_not_only_rls` runs on an ADMIN cursor: on the app pool `0008`'s policy would
block a cross-owner delete anyway, so an owner-scoping test there passes whether or not the
predicate exists and proves nothing about the predicate.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from typing import Any
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import admin_connection, tenant_connection
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, Tenant
from healthee.db import migrate, rederive
from healthee.db.stale_derived import purge_stale, stale_counts
from healthee.ingest import HelioPayload, ingest_helio
from healthee.ingest.service import DerivePlan

pytestmark = pytest.mark.integration

_TABLES = "sample, sleep_session, workout, derived_daily, weight_log, profile"

# The owner every test repairs, as `rederive_owner` takes it (the CLI resolves the same
# thing through `active_users`).
_SENTINEL = Tenant(id=SENTINEL_USER_ID, tz=SENTINEL_TZ)

_SLEEP_HR_BPM = 52.0

# A second active owner, so "bounded by owner" is a claim about real rows rather than an
# empty set. Deleted in teardown — a leaked app_user row makes every later `--user`-less
# run in the session slower and any active_users() assertion unreproducible.
_OTHER_OWNER = UUID("11111111-1111-1111-1111-111111111111")

# The metric the incident was about: with `profile.srpa` unanswered, `derive/vo2max.py`
# correctly writes NOTHING, so a stored row for it is exactly a row today's code would not
# produce. Nothing here depends on how that estimate is computed — only that it is withheld.
_WITHHELD_METRIC = "vo2max_estimate"

# A metric the night pass genuinely writes from the seeded HR, i.e. one a repair must
# recompute rather than remove.
_LIVE_METRIC = "rhr_daily"

# A SECOND stale metric, for the metric bound. The seeded night has heart rate and no HRV,
# so `derive/hrv_spo2_resp.py` writes nothing for it and a planted row stays untouched —
# genuinely stale, and therefore genuinely at risk from an unbounded purge.
_OTHER_STALE_METRIC = "hrv_sleep_avg"


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def _skip_derive(conn: Any, user_id: UUID, tz: str, plan: DerivePlan) -> None:  # noqa: ARG001
    """Ingest without deriving — the state a stalled derive layer leaves behind."""


def _seed_last_night() -> date:
    """Push one night of raw data with derivation suppressed. Returns its wake date."""
    wake = datetime.now(tz=UTC).replace(minute=0, second=0, microsecond=0) - timedelta(hours=2)
    start = wake - timedelta(hours=7)
    samples, ts = [], start
    while ts < wake:
        samples.append({"metric": "hr", "ts": _ms(ts), "value": _SLEEP_HR_BPM})
        ts += timedelta(minutes=1)
    payload = HelioPayload.model_validate(
        {
            "samples": samples,
            "sleep": [
                {
                    "start_ts": _ms(start),
                    "end_ts": _ms(wake),
                    "kind": "main",
                    "rem_min": 80,
                    "light_min": 220,
                    "deep_min": 80,
                    "wake_min": 40,
                    "stages": [[_ms(start), _ms(wake), 2]],
                }
            ],
            "profile": {"height_cm": 175.0, "sex": "male", "dob": "1990-06-15", "weight_kg": 70.0},
        }
    )
    ingest_helio(payload, SENTINEL_USER_ID, SENTINEL_TZ, derive=_skip_derive)
    return wake.astimezone(ZoneInfo(SENTINEL_TZ)).date()


def _plant(day: date, metric: str, value: float, user_id: UUID = SENTINEL_USER_ID) -> None:
    """A row written by code that no longer exists — old value, old `derived_at`."""
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags, derived_at) "
            "VALUES (%s, %s, %s, %s, '{}'::jsonb, now() - interval '30 days') "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET "
            "  value = EXCLUDED.value, derived_at = EXCLUDED.derived_at",
            (user_id, day, metric, value),
        )


def _rows(user_id: UUID = SENTINEL_USER_ID) -> dict[tuple[date, str], float]:
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute("SELECT day, metric, value FROM derived_daily WHERE user_id = %s", (user_id,))
        return {(row[0], row[1]): float(row[2]) for row in cur.fetchall()}


@pytest.fixture
def seeded(db: None) -> Iterator[date]:  # noqa: ARG001 — gates on DB reachability
    """One night of raw data, a second owner, and an empty derived layer."""
    migrate.apply_migrations()
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(f"TRUNCATE {_TABLES}")
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO UPDATE SET timezone = EXCLUDED.timezone",
            (_OTHER_OWNER, "stale-scoping@example.test", SENTINEL_TZ),
        )
    yield _seed_last_night()
    with admin_connection() as conn, conn.cursor() as cur:
        cur.execute(f"TRUNCATE {_TABLES}")
        cur.execute("DELETE FROM app_user WHERE id = %s", (_OTHER_OWNER,))


def _repair(*extra: str) -> int:
    return rederive.main(["--user", str(SENTINEL_USER_ID), "--days", "3", *extra])


# ── the repair itself ────────────────────────────────────────────────────────


def test_a_row_todays_code_would_not_write_is_removed(seeded: date) -> None:
    """The #118 case end to end: a withheld metric's orphan row does not survive a purge."""
    _plant(seeded, _WITHHELD_METRIC, 51.1)

    assert _repair("--purge-stale", _WITHHELD_METRIC, "--apply") == 0

    assert (seeded, _WITHHELD_METRIC) not in _rows()


def test_a_row_todays_code_would_write_is_recomputed_not_lost(seeded: date) -> None:
    """The other half, and the one that makes the purge safe: live rows are rebuilt.

    The planted value is deliberately wrong, so "still present" cannot pass by the row
    merely having been left alone — it has to carry the recomputed number.
    """
    _plant(seeded, _LIVE_METRIC, 999.0)

    assert _repair("--purge-stale", _LIVE_METRIC, "--apply") == 0

    assert _rows()[(seeded, _LIVE_METRIC)] == pytest.approx(_SLEEP_HR_BPM)


def test_a_plain_run_finds_the_stale_rows_without_being_asked(seeded: date) -> None:
    """The detection check: an ordinary repair sees what it did not rewrite, and keeps it.

    This is what would have caught the incident without a person querying production by
    hand — so it must happen on the DEFAULT invocation, with no flag.
    """
    _plant(seeded, _WITHHELD_METRIC, 51.1)

    result = rederive.rederive_owner(_SENTINEL, days=3)

    assert result.stale == {_WITHHELD_METRIC: 1}
    assert result.purged is None, "a plain run must not reach the destructive path at all"
    assert (seeded, _WITHHELD_METRIC) in _rows(), "a plain run must not delete anything"


def test_a_plain_run_says_so_in_the_log(seeded: date, caplog: pytest.LogCaptureFixture) -> None:
    """…and it says so where an operator will read it, unprompted.

    Driven through :func:`rederive.run` rather than ``main``, deliberately:
    ``core.logging.configure_logging`` clears the root handlers on its FIRST call in a
    process, which silently removes pytest's capture handler. A caplog assertion behind
    ``main()`` therefore passes or fails on test ORDER, and a vacuously-empty
    ``caplog.text`` makes a negative assertion pass while proving nothing.
    """
    _plant(seeded, _WITHHELD_METRIC, 51.1)

    with caplog.at_level("WARNING", logger="healthee.db.rederive"):
        assert rederive.run(SENTINEL_USER_ID, 3) == 0

    assert "STALE" in caplog.text
    assert f"{_WITHHELD_METRIC}: 1" in caplog.text


# ── the destructive path does not fire unless asked ──────────────────────────


def test_naming_metrics_without_apply_only_previews(seeded: date) -> None:
    """--purge-stale alone is a plan. Nothing goes until --apply says so."""
    _plant(seeded, _WITHHELD_METRIC, 51.1)

    assert _repair("--purge-stale", _WITHHELD_METRIC) == 0

    assert (seeded, _WITHHELD_METRIC) in _rows()


def test_apply_without_naming_a_metric_is_refused(seeded: date) -> None:
    """ "Delete whatever you found" is not a spelling this tool has."""
    _plant(seeded, _WITHHELD_METRIC, 51.1)

    assert _repair("--apply") == 2

    assert (seeded, _WITHHELD_METRIC) in _rows()


def test_a_gated_metric_is_refused_until_its_gate_is_reopened(seeded: date) -> None:
    """An already-scored GPS session's row only LOOKS stale — purging it would be a loss.

    `derive/gps_scoring.py` scores a track at most once, so a plain run never re-attempts
    it. The refusal names the flag that fixes it rather than deleting correct data.
    """
    _plant(seeded, "vo2max_submax", 42.3)

    assert _repair("--purge-stale", "vo2max_submax", "--apply") == 2

    assert (seeded, "vo2max_submax") in _rows()


def test_a_gated_metric_is_left_out_of_the_stale_report(seeded: date) -> None:
    """…and it is not reported either, or the warning cries wolf on every run and is ignored.

    Asserted on the returned counts rather than on the log, for the reason
    :func:`test_a_plain_run_says_so_in_the_log` documents: an empty ``caplog.text`` would
    make this negative assertion pass while testing nothing at all.
    """
    _plant(seeded, "vo2max_submax", 42.3)

    assert rederive.rederive_owner(_SENTINEL, days=3).stale == {}


# ── the bounds ───────────────────────────────────────────────────────────────


def test_another_metrics_stale_rows_survive(seeded: date) -> None:
    """The metric bound: only what the operator named may go.

    ``_OTHER_STALE_METRIC`` is stale by the same rule as the named one — the seeded night
    carries no HRV samples, so nothing rewrites it — which is what makes this a test of the
    bound rather than of the row happening to be fresh.
    """
    _plant(seeded, _WITHHELD_METRIC, 51.1)
    _plant(seeded, _OTHER_STALE_METRIC, 4321.0)

    assert _repair("--purge-stale", _WITHHELD_METRIC, "--apply") == 0

    rows = _rows()
    assert (seeded, _WITHHELD_METRIC) not in rows
    assert rows[(seeded, _OTHER_STALE_METRIC)] == pytest.approx(4321.0)


def test_rows_outside_the_window_survive(seeded: date) -> None:
    """The window bound: a repair of three days is not a licence over the whole history."""
    outside = seeded - timedelta(days=40)
    _plant(seeded, _WITHHELD_METRIC, 51.1)
    _plant(outside, _WITHHELD_METRIC, 48.0)

    assert _repair("--purge-stale", _WITHHELD_METRIC, "--apply") == 0

    rows = _rows()
    assert (seeded, _WITHHELD_METRIC) not in rows
    assert rows[(outside, _WITHHELD_METRIC)] == pytest.approx(48.0)


def test_another_owners_rows_survive_a_repair_under_rls(seeded: date) -> None:
    """The owner bound as the CLI actually runs it — on the least-privilege app role."""
    _plant(seeded, _WITHHELD_METRIC, 51.1)
    _plant(seeded, _WITHHELD_METRIC, 44.4, user_id=_OTHER_OWNER)

    assert _repair("--purge-stale", _WITHHELD_METRIC, "--apply") == 0

    assert (seeded, _WITHHELD_METRIC) not in _rows()
    assert _rows(_OTHER_OWNER)[(seeded, _WITHHELD_METRIC)] == pytest.approx(44.4)


def test_the_owner_bound_is_the_predicate_not_only_rls(seeded: date) -> None:
    """`purge_stale`'s OWN `user_id = %s`, proven where RLS cannot be doing the work.

    Standards §2: RLS is the backstop, the explicit predicate is the filter. On the app
    pool `0008`'s policy would block a cross-owner delete regardless, so this runs on the
    ADMIN connection — which bypasses RLS — and is therefore the only place a missing
    predicate is observable at all.
    """
    _plant(seeded, _WITHHELD_METRIC, 51.1)
    _plant(seeded, _WITHHELD_METRIC, 44.4, user_id=_OTHER_OWNER)

    with admin_connection() as conn, conn.cursor() as cur:
        removed = purge_stale(cur, SENTINEL_USER_ID, (seeded, seeded), [_WITHHELD_METRIC])

    assert removed == {_WITHHELD_METRIC: 1}
    assert _rows(_OTHER_OWNER)[(seeded, _WITHHELD_METRIC)] == pytest.approx(44.4)


def test_an_empty_metric_list_removes_nothing(seeded: date) -> None:
    """`metric = ANY('{}')` matches no row — there is no "all metrics" spelling."""
    _plant(seeded, _WITHHELD_METRIC, 51.1)

    with admin_connection() as conn, conn.cursor() as cur:
        removed = purge_stale(cur, SENTINEL_USER_ID, (seeded, seeded), [])

    assert removed == {}
    assert (seeded, _WITHHELD_METRIC) in _rows()


# ── the counts are the rows ──────────────────────────────────────────────────


def test_the_reported_counts_are_the_rows_that_went(seeded: date) -> None:
    """Reported by the DELETE's own RETURNING, so it cannot report what it did not do.

    Three days planted, three days removed, one number — the run in the incident said
    "done" while removing nothing, which is the failure being fixed.
    """
    days = [seeded - timedelta(days=n) for n in range(3)]
    for day in days:
        _plant(day, _WITHHELD_METRIC, 51.1)
    before = len(_rows())

    with admin_connection() as conn, conn.cursor() as cur:
        removed = purge_stale(cur, SENTINEL_USER_ID, (days[-1], days[0]), [_WITHHELD_METRIC])

    assert removed == {_WITHHELD_METRIC: 3}
    assert len(_rows()) == before - 3


def test_the_scan_only_counts_rows_this_transaction_did_not_write(seeded: date) -> None:
    """The discriminator itself: a row the open transaction just wrote is never stale.

    Run against the derive path's own transaction shape, because the whole answer depends
    on the scan sharing a transaction with the writes it is judging.
    """
    _plant(seeded, _WITHHELD_METRIC, 51.1)

    with tenant_connection(SENTINEL_USER_ID) as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value, flags, derived_at) "
            "VALUES (%s, %s, %s, %s, '{}'::jsonb, now())",
            (SENTINEL_USER_ID, seeded, "fresh_marker_metric", 1.0),
        )
        counts = stale_counts(cur, SENTINEL_USER_ID, (seeded, seeded))

    assert counts == {_WITHHELD_METRIC: 1}
