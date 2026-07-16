"""Owner B — the SECOND tenant, layered over the ``seed`` fixture (Phase 6.3c, §10).

Kept apart from ``seed.py`` because it is a different responsibility: ``seed`` builds
the canonical single-owner fixture the committed contract snapshots are taken from,
and this module deliberately does NOT touch it. Owner A stays the sentinel and keeps
owning every row ``seed_all`` writes, so importing this module changes no snapshot;
only a test that calls ``seed_owner_b()`` sees B at all.

The design rule for every row here: write it at the SAME natural key as A's
equivalent (same days, same session/workout start_ts, same manual-entry kinds) with a
value that would be IMPOSSIBLE for A. Only ``user_id`` then separates the two, so an
unscoped read cannot accidentally return the right answer — it returns an absurd
number, which is what makes the leakage suite's assertions meaningful.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from uuid import UUID

from tests.contracts.seed import USER_TZ, today_local

from healthee.core.db import tenant_transaction, transaction

# A real second owner, in a DIFFERENT timezone — per MULTI_USER.md §10 multi-tz is
# first-class, so the fixture must not accidentally prove isolation only for owners
# who happen to share a day boundary.
OWNER_B = UUID("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
OWNER_B_TZ = "America/Chicago"

# Values chosen to be impossible for owner A (A: ~8200 steps, 55 rhr, 72 recovery).
B_STEPS = 22000.0
B_RHR = 88.0
B_RECOVERY = 12.0
B_NAME = "OwnerB"


def seed_owner_b() -> None:
    """Layer a SECOND owner's data over the ``seed_all`` fixture. Additive + idempotent.

    Deliberately writes B's rows at the SAME natural keys as A's (same days, same
    session/workout start, same manual-entry kinds) so that only ``user_id`` can tell
    the two apart. A read that forgets its owner filter therefore cannot accidentally
    return the right thing — it returns B's impossible numbers or double the rows.
    """
    # `app_user` is an IDENTITY table and carries no RLS policy (0008) — the app has
    # to resolve who you are before it can know the owner to scope to. So B's row is
    # created on a plain transaction; everything after it is tenant data and needs
    # the owner set, or 0008's WITH CHECK denies the write.
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO NOTHING",
            (OWNER_B, "owner-b@example.test", OWNER_B_TZ),
        )
    with tenant_transaction(OWNER_B) as cur:
        today = today_local()
        _seed_b_profile(cur)
        _seed_b_derived(cur, today)
        _seed_b_sleep_and_workout(cur, today)
        _seed_b_rows(cur, today)


def _seed_b_profile(cur) -> None:
    """B's own profile — impossible before 0005, when `id = 1` allowed one row total."""
    cur.execute(
        "INSERT INTO profile (user_id, name, height_cm, sex, dob) "
        "VALUES (%s,%s,150,'female','1970-02-03') "
        "ON CONFLICT (user_id) DO UPDATE SET name=EXCLUDED.name",
        (OWNER_B, B_NAME),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now(), 99.9) "
        "ON CONFLICT (user_id, ts) DO NOTHING",
        (OWNER_B,),
    )


def _seed_b_derived(cur, today: date) -> None:
    """B's derived_daily over the same 30-day window A uses — same (day, metric) keys."""
    for n in range(30):
        day = today - timedelta(days=n)
        for metric, value in (
            ("steps_total", B_STEPS),
            ("rhr_daily", B_RHR),
            ("recovery_score", B_RECOVERY),
            ("hrv_sleep_avg", 12.0),
            ("sleep_health_score_4dim", 0.0),
            ("total_calories", 4000.0),
            ("mvpa_min", 99.0),
            ("cardio_load", 200.0),
            ("vo2max_estimate", 20.0),
            ("sleep_debt_min", 900.0),
            ("sleep_need_min", 400.0),
            ("distance_m_daily", 19000.0),
        ):
            cur.execute(
                "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
                "VALUES (%s,%s,%s,%s,'{}'::jsonb) "
                "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
                (OWNER_B, day, metric, value),
            )


def _seed_b_sleep_and_workout(cur, today: date) -> None:
    """B's session/workout at the SAME start_ts as A's — only the owner separates them."""
    start = datetime.combine(today - timedelta(days=1), time(23, 0), tzinfo=USER_TZ)
    end = datetime.combine(today, time(6, 30), tzinfo=USER_TZ)
    cur.execute(
        "INSERT INTO sleep_session "
        "(user_id,start_ts,end_ts,kind,score,avg_hr,rem_min,light_min,deep_min,wake_min,stages) "
        "VALUES (%s,%s,%s,'main',9,99,1,2,3,180,'[]'::jsonb) "
        "ON CONFLICT (user_id, start_ts) DO NOTHING",
        (OWNER_B, start.astimezone(UTC), end.astimezone(UTC)),
    )
    w_start = datetime.combine(today, time(7, 0), tzinfo=USER_TZ).astimezone(UTC)
    cur.execute(
        "INSERT INTO workout "
        "(user_id,start_ts,sport,duration_s,calories,distance_m,avg_hr,max_hr,min_hr) "
        "VALUES (%s,%s,9,9999,9999,99999,199,220,180) "
        "ON CONFLICT (user_id, start_ts) DO NOTHING",
        (OWNER_B, w_start),
    )
    cur.execute(
        "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s,%s,'hr',199) "
        "ON CONFLICT (user_id, metric, ts) DO UPDATE SET value = EXCLUDED.value",
        (OWNER_B, w_start),
    )


def _seed_b_rows(cur, today: date) -> None:
    """B's logs / illness / recs / findings / GPS — same shapes, unmistakable values."""
    cur.execute(
        "INSERT INTO manual_entry (user_id, kind, ts, amount, unit) "
        "VALUES (%s, 'caffeine', now(), 999, 'mg')",
        (OWNER_B,),
    )
    cur.execute(
        "INSERT INTO illness_flag (user_id, date, severity, rr_delta_bpm, temp_delta_c, "
        "sustained, research_note_ids) VALUES (%s,%s,'high',9.9,2.2,true,%s) "
        "ON CONFLICT (user_id, date) DO NOTHING",
        (OWNER_B, today, ["respiratory_rate_normal"]),
    )
    cur.execute(
        "INSERT INTO recommendation (user_id, date, rank, action, rationale, expected_effect, "
        "category, evidence_grade, research_note_ids, signal_source) VALUES "
        "(%s,%s,1,'OWNER B ACTION','B rationale','B effect','sleep',3,%s,'sleep_debt') "
        "ON CONFLICT (user_id, date, rank) DO NOTHING",
        (OWNER_B, today, ["sleep_need_debt"]),
    )
    cur.execute(
        "INSERT INTO finding (user_id, kind, description, metric_a, metric_b, lag_days, "
        "effect_size, effect_metric, p_value, q_value, n_samples, significant, "
        "research_note_ids) VALUES (%s,'pairwise_lag','OWNER B FINDING','caffeine',"
        "'sleep_health_score_4dim',0,-0.99,'rho',0.001,0.002,99,true,%s) "
        "ON CONFLICT DO NOTHING",
        (OWNER_B, ["caffeine_sleep"]),
    )
    start = datetime.now(tz=UTC) - timedelta(hours=2)
    cur.execute(
        "INSERT INTO gps_track (user_id,start_ts,end_ts,source,distance_m,duration_s,avg_hr,"
        "ele_gain_m,vo2max_submax,r2) VALUES (%s,%s,%s,'phone',99999,9999,199,999,20.0,0.99) "
        "RETURNING id",
        (OWNER_B, start, start + timedelta(minutes=30)),
    )
    track_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO gps_point (user_id, track_id, ts, lat, lng, ele_m) "
        "VALUES (%s,%s,%s,50.0,-90.0,999) ON CONFLICT DO NOTHING",
        (OWNER_B, track_id, start),
    )
