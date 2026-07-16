"""Seed helpers for the sentinel-claim suite (`test_claim_sentinel.py`).

Split out of the test module for the 400-line file gate: this half is the DB
scaffolding (one row in every tenant table, the "real owner just signed in" setup,
and the teardown), the other half is the assertions. The `claimable` fixture that
drives these lives in `conftest.py`.

The teardown matters more than test scaffolding usually does: a successful claim
DELETES the sentinel's `app_user` row, and every other integration suite in the
session owns its data as the sentinel — so `restore_sentinel` re-keys back (the same
cascade, in reverse) rather than leaving the database unusable behind it.
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from uuid import UUID

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

# The "real" owner: signed in with Supabase, so JIT-provisioned with their real
# identity — the common case the tool is built for.
TARGET = UUID("77777777-7777-7777-7777-777777777777")
TARGET_EMAIL = "real.owner@example.test"
TARGET_TZ = "America/Chicago"  # deliberately NOT the sentinel's Asia/Kolkata

# A third owner, used to prove the tool refuses an ambiguous merge.
OCCUPIED = UUID("88888888-8888-8888-8888-888888888888")

# Far-future markers so these rows can never collide with another suite's seed.
TS = datetime(2998, 3, 4, 12, 0, tzinfo=UTC)
DAY = date(2998, 3, 4)
MARK = "claim-sentinel-test"


def seed_every_tenant_table(cur, user_id: UUID) -> None:
    """One row per tenant table, so "moves EVERY table" is actually observable."""
    cur.execute(
        "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, 'hr', 61) "
        "ON CONFLICT DO NOTHING",
        (user_id, TS),
    )
    cur.execute(
        "INSERT INTO sleep_session (user_id, start_ts, end_ts) VALUES (%s, %s, %s) "
        "ON CONFLICT DO NOTHING",
        (user_id, TS, TS),
    )
    cur.execute(
        "INSERT INTO workout (user_id, start_ts) VALUES (%s, %s) ON CONFLICT DO NOTHING",
        (user_id, TS),
    )
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s, %s, %s, 7) "
        "ON CONFLICT DO NOTHING",
        (user_id, DAY, MARK),
    )
    cur.execute(
        "INSERT INTO profile (user_id, name) VALUES (%s, %s) ON CONFLICT DO NOTHING",
        (user_id, MARK),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, 70) ON CONFLICT DO NOTHING",
        (user_id, TS),
    )
    cur.execute(
        "INSERT INTO kv (user_id, key, value) VALUES (%s, %s, '1') ON CONFLICT DO NOTHING",
        (user_id, MARK),
    )
    cur.execute(
        "INSERT INTO manual_entry (user_id, kind, ts, name) VALUES (%s, 'caffeine', %s, %s)",
        (user_id, TS, MARK),
    )
    cur.execute(
        "INSERT INTO illness_flag (user_id, date, severity, research_note_ids) "
        "VALUES (%s, %s, 'high', ARRAY[%s]) ON CONFLICT DO NOTHING",
        (user_id, DAY, MARK),
    )
    cur.execute(
        "INSERT INTO recommendation (user_id, date, rank, action, rationale, category, "
        "  evidence_grade, research_note_ids, signal_source) "
        "VALUES (%s, %s, 1, %s, 'because', 'sleep', 3, ARRAY[%s], %s) ON CONFLICT DO NOTHING",
        (user_id, DAY, MARK, MARK, MARK),
    )
    cur.execute(
        "INSERT INTO finding (user_id, kind, description, metric_a, effect_size, "
        "  effect_metric, p_value, n_samples) VALUES (%s, %s, 'd', 'hr', 0.4, 'r', 0.01, 30) "
        "ON CONFLICT DO NOTHING",
        (user_id, MARK),
    )
    _seed_challenge_and_gps(cur, user_id)


def _seed_challenge_and_gps(cur, user_id: UUID) -> None:
    """The four tables with intra-tenant FKs (challenge/outcome, track/point)."""
    cur.execute(
        "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
        "  target_value, cadence, window_days) "
        "VALUES (%s, %s, 'w', 'sleep', 'steps_total', '>=', 1, 'daily', 7) RETURNING id",
        (user_id, MARK),
    )
    challenge_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO program (user_id, title, why) VALUES (%s, %s, 'w')",
        (user_id, MARK),
    )
    cur.execute(
        "INSERT INTO challenge_outcome (user_id, challenge_id, status) VALUES (%s, %s, %s)",
        (user_id, challenge_id, MARK),
    )
    cur.execute(
        "INSERT INTO gps_track (user_id, start_ts, end_ts, source) VALUES (%s, %s, %s, %s) "
        "RETURNING id",
        (user_id, TS, TS, MARK),
    )
    track_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO gps_point (user_id, track_id, ts, lat, lng) VALUES (%s, %s, %s, 1.0, 2.0) "
        "ON CONFLICT DO NOTHING",
        (user_id, track_id, TS),
    )


def provision(cur, user_id: UUID, email: str, tz: str) -> None:
    """What a first Supabase sign-in leaves behind: an app_user row and nothing else."""
    cur.execute(
        "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
        "ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, timezone = EXCLUDED.timezone",
        (user_id, email, tz),
    )


def restore_sentinel(cur) -> None:
    """Undo a successful claim by re-keying back — the same cascade, in reverse.

    A test that leaves the DB with no sentinel row would break every other suite in
    the session (they all own their data as the sentinel), so this is not optional
    tidying.
    """
    cur.execute("SELECT 1 FROM app_user WHERE id = %s", (SENTINEL_USER_ID,))
    if cur.fetchone() is None:
        cur.execute(
            "UPDATE app_user SET id = %s, email = NULL, timezone = %s WHERE id = %s",
            (SENTINEL_USER_ID, SENTINEL_TZ, TARGET),
        )


def delete_marked(cur) -> None:
    """Remove only the rows these tests seeded, wherever they now live."""
    cur.execute("DELETE FROM gps_point WHERE ts = %s", (TS,))
    cur.execute("DELETE FROM gps_track WHERE source = %s", (MARK,))
    cur.execute("DELETE FROM challenge_outcome WHERE status = %s", (MARK,))
    cur.execute("DELETE FROM challenge WHERE title = %s", (MARK,))
    cur.execute("DELETE FROM program WHERE title = %s", (MARK,))
    cur.execute("DELETE FROM finding WHERE kind = %s", (MARK,))
    cur.execute("DELETE FROM recommendation WHERE signal_source = %s", (MARK,))
    cur.execute("DELETE FROM illness_flag WHERE date = %s", (DAY,))
    cur.execute("DELETE FROM manual_entry WHERE name = %s", (MARK,))
    cur.execute("DELETE FROM kv WHERE key = %s", (MARK,))
    cur.execute("DELETE FROM weight_log WHERE ts = %s", (TS,))
    cur.execute("DELETE FROM profile WHERE name = %s", (MARK,))
    cur.execute("DELETE FROM derived_daily WHERE metric = %s", (MARK,))
    cur.execute("DELETE FROM workout WHERE start_ts = %s", (TS,))
    cur.execute("DELETE FROM sleep_session WHERE start_ts = %s", (TS,))
    cur.execute("DELETE FROM sample WHERE ts = %s", (TS,))
    cur.execute("DELETE FROM device_token WHERE label = %s", (MARK,))
