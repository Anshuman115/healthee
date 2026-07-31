"""Deterministic v2 dataset for the WP7 read-endpoint contract + integration tests.

Seeds every table a read endpoint touches with a small, KNOWN fixture anchored to
the user timezone so a snapshot is reproducible: profile, weight, raw samples,
sleep sessions (+ a nap), a workout, the ``derived_daily`` rows (with the flags the
payloads read), manual entries (+ an open fast), an illness flag, a recommendation,
a finding, and a GPS track. Values are chosen so derived numbers are stable.

**Owner A is the sentinel** and owns every row seeded here, so the committed
contract snapshots stay byte-identical. Every insert names that owner explicitly:
`0007` dropped the transitional `user_id` DEFAULT, so a seed that omitted it now
raises `NotNullViolation` instead of quietly landing on the sentinel — which is the
point (a seeder leaning on a default is a seeder that can't seed a second tenant).

The second tenant lives in the sibling
``seed_owner_b`` module (Phase 6.3c, MULTI_USER.md §10): additive and opt-in, so a
test that doesn't call it is unaffected by B's existence.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from tests.contracts.seed_challenges import seed_challenges, seed_program

from healthee.core.db import admin_connection, tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate

# The sentinel owner's zone — the seed anchors its local days exactly as the read
# layer does (6.3b threads the IANA name; ZoneInfo is built once here).
USER_TZ = ZoneInfo(SENTINEL_TZ)

_TABLES = (
    "sample, sleep_session, workout, derived_daily, weight_log, profile, manual_entry, "
    "illness_flag, recommendation, finding, gps_track, gps_point, kv, program, challenge"
)

# `challenge` is truncated with CASCADE because `challenge_outcome` references it —
# and taking the ledger with it is right for a reset: an outcome whose challenge is
# gone is orphan history nothing can explain.
_TRUNCATE_MODIFIER = " CASCADE"


def _ms(dt: datetime) -> float:
    return dt.timestamp() * 1000


def reset() -> None:
    """Apply migrations and truncate every table the read layer reads.

    The ADMIN path (`admin_connection`), because all three halves are owner-only:
    the migrations are DDL, `TRUNCATE` is never granted to the app role — the app
    must not be able to erase a life's health data (6.5b-1, MULTI_USER.md §3.3) —
    and TRUNCATE must clear EVERY owner's rows, which an RLS-scoped connection could
    not do. The seeding INSERTs that follow deliberately stay on the app pool
    (`seed_all`), so the fixture exercises the privileges the running app has.
    """
    migrate.apply_migrations()
    with admin_connection() as conn, conn.cursor() as cur:
        # Trusted SQL — a module-level constant list of table names, never input.
        cur.execute(f"TRUNCATE {_TABLES}{_TRUNCATE_MODIFIER}")


def today_local() -> date:
    """Today in the sentinel owner's zone — the anchor both owners' fixtures share."""
    return datetime.now(tz=USER_TZ).date()


def seed_all() -> None:
    """Populate the whole fixture in one transaction, as the sentinel owner.

    `tenant_transaction`, not `transaction`: every table below carries a `0008` RLS
    policy, so an INSERT with no owner set on the session is denied by the policy's
    WITH CHECK. The seed runs on the APP POOL (as the least-privilege role) on
    purpose — a fixture that seeded as the admin would bypass RLS and prove nothing
    about the privileges the running app actually has.
    """
    reset()
    today = today_local()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_profile(cur)
        _seed_samples(cur, today)
        _seed_sleep(cur, today)
        _seed_workout(cur, today)
        _seed_derived(cur, today)
        _seed_manual(cur)
        _seed_illness(cur, today)
        _seed_recommendation(cur, today)
        _seed_finding(cur)
        _seed_gps(cur)
        seed_challenges(cur, today, USER_TZ)
        seed_program(cur, today, USER_TZ)


def _seed_profile(cur) -> None:
    cur.execute(
        "INSERT INTO profile (user_id, name, height_cm, sex, dob) "
        "VALUES (%s,'Test',176,'male','1990-05-01') "
        "ON CONFLICT (user_id) DO UPDATE SET name=EXCLUDED.name",
        (SENTINEL_USER_ID,),
    )
    cur.execute(
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now(), 72.5) ON CONFLICT DO NOTHING",
        (SENTINEL_USER_ID,),
    )


def _seed_samples(cur, today: date) -> None:
    """Intraday raw samples for today (drives HR/step/stress shapes + data-health)."""
    base = datetime.combine(today, time(6, 0), tzinfo=USER_TZ).astimezone(UTC)
    rows: list[tuple] = []
    for i in range(48):  # every 15 min from 06:00, ~12h of data
        ts = base + timedelta(minutes=15 * i)
        rows.append((SENTINEL_USER_ID, ts, "hr", 62 + (i % 20)))
        rows.append((SENTINEL_USER_ID, ts, "steps_per_minute", 40 + (i % 30)))
        rows.append((SENTINEL_USER_ID, ts, "stress", 30 + (i % 25)))
    for metric, val in (
        ("hrv", 45.0),
        ("spo2", 97.0),
        ("respiratory_rate", 14.0),
        ("skin_temp_c", 33.2),
    ):
        rows.append((SENTINEL_USER_ID, base, metric, val))
    cur.executemany(
        "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s,%s,%s,%s) "
        "ON CONFLICT DO NOTHING",
        rows,
    )


def _seed_sleep(cur, today: date) -> None:
    """Seven main nights + one nap. Stages carry a small hypnogram so timelines
    render and the physiology window has data."""
    for n in range(7):
        wake_date = today - timedelta(days=n)
        start = datetime.combine(wake_date - timedelta(days=1), time(23, 0), tzinfo=USER_TZ)
        end = datetime.combine(wake_date, time(6, 30), tzinfo=USER_TZ)
        stages = [
            [int(_ms(start)), int(_ms(start + timedelta(minutes=200))), 4],
            [int(_ms(start + timedelta(minutes=200))), int(_ms(start + timedelta(minutes=290))), 5],
            [int(_ms(start + timedelta(minutes=290))), int(_ms(end)), 8],
        ]
        cur.execute(
            "INSERT INTO sleep_session "
            "(user_id,start_ts,end_ts,kind,score,avg_hr,rem_min,light_min,deep_min,wake_min,stages)"
            " VALUES (%s,%s,%s,'main',86,58,90,200,90,20,%s) "
            "ON CONFLICT (user_id, start_ts) DO NOTHING",
            (SENTINEL_USER_ID, start.astimezone(UTC), end.astimezone(UTC), json.dumps(stages)),
        )
    nap_start = datetime.combine(today, time(14, 0), tzinfo=USER_TZ)
    nap_end = nap_start + timedelta(minutes=35)
    cur.execute(
        "INSERT INTO sleep_session "
        "(user_id,start_ts,end_ts,kind,rem_min,light_min,deep_min,wake_min,stages) "
        "VALUES (%s,%s,%s,'nap',0,30,5,0,'[]'::jsonb) "
        "ON CONFLICT (user_id, start_ts) DO NOTHING",
        (SENTINEL_USER_ID, nap_start.astimezone(UTC), nap_end.astimezone(UTC)),
    )


def _seed_workout(cur, today: date) -> None:
    start = datetime.combine(today, time(7, 0), tzinfo=USER_TZ).astimezone(UTC)
    cur.execute(
        "INSERT INTO workout "
        "(user_id,start_ts,sport,duration_s,calories,distance_m,avg_hr,max_hr,min_hr) "
        "VALUES (%s,%s,1,1800,250,4200,135,168,95) ON CONFLICT (user_id, start_ts) DO NOTHING",
        (SENTINEL_USER_ID, start),
    )
    # Minute HR inside the workout window so the detail endpoint has a profile.
    cur.executemany(
        "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s,%s,'hr',%s) "
        "ON CONFLICT DO NOTHING",
        [(SENTINEL_USER_ID, start + timedelta(minutes=i), 120 + (i % 40)) for i in range(30)],
    )


def _dd(cur, day: date, metric: str, value: float, flags: dict | None = None) -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) VALUES (%s,%s,%s,%s,%s) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET "
        "value=EXCLUDED.value, flags=EXCLUDED.flags",
        (SENTINEL_USER_ID, day, metric, value, json.dumps(flags or {})),
    )


def _seed_derived(cur, today: date) -> None:
    """derived_daily rows across a 30-day window (steady values → stable baselines)."""
    for n in range(30):
        day = today - timedelta(days=n)
        _seed_derived_day(cur, day, today)


def _seed_derived_day(cur, day: date, today: date) -> None:
    sleep_flags = {
        "tst_min": 380,
        "tib_min": 450,
        "efficiency_pct": 84.4,
        "midpoint_local": f"{day.isoformat()}T02:45:00+05:30",
        "session_source": "zepp_cloud",
        "sri": 74.0,
    }
    _dd(cur, day, "rhr_daily", 55.0, {"n": 120})
    _dd(cur, day, "hrv_sleep_avg", 45.0)
    _dd(cur, day, "spo2_overnight", 97.0)
    _dd(cur, day, "spo2_overnight_min", 93.0)
    _dd(cur, day, "respiratory_rate_sleep", 14.0)
    _dd(cur, day, "sleep_health_score_4dim", 3, sleep_flags)
    for dim in ("duration", "efficiency", "timing", "regularity"):
        _dd(cur, day, f"sleep_dim_{dim}", 1 if dim != "timing" else 0, sleep_flags)
    _dd(cur, day, "sleep_regularity_index", 74.0, sleep_flags)
    _dd(cur, day, "sleep_need_min", 480.0, {"basis": "NSF2015", "age": 35})
    _dd(
        cur,
        day,
        "sleep_debt_min",
        120.0,
        {
            "window_nights": 14,
            "nights": 14,
            "avg_tst_min": 380,
            "avg_deficit_min": 100,
            "nights_below": 12,
        },
    )
    _dd(cur, day, "steps_total", 8200.0)
    _dd(cur, day, "distance_m_daily", 6100.0, {"method": "stride", "stride_m": 0.744})
    _dd(cur, day, "total_calories", 2350.0)
    _dd(cur, day, "active_calories", 620.0)
    _dd(cur, day, "basal_calories", 1730.0)
    _dd(cur, day, "mvpa_min", 32.0, {"moderate": 24, "vigorous": 4})
    _dd(
        cur,
        day,
        "cardio_load",
        55.0,
        {
            "method": "banister",
            "hrmax": 185,
            "rhr": 55,
            "zone_min": [20, 15, 8, 3, 1],
            "edwards_tl": 120,
            "hr_minutes": 47,
        },
    )
    _dd(
        cur,
        day,
        "recovery_score",
        72.0,
        {
            "factors": {
                "sleep": {"sub": 60},
                "hrv": {"sub": 80},
                "rhr": {"sub": 70},
                "rr": {"sub": 75},
            },
            "weights": {"sleep": 0.4, "hrv": 0.3, "rhr": 0.2, "rr": 0.1},
        },
    )
    _dd(
        cur,
        day,
        "vo2max_estimate",
        41.5,
        {
            "rhr_med": 55.0,
            "srpa": 3,
            "bmi": 23.4,
            "age_years": 35,
            "sex": "male",
            "see_ml_kg_min": 5.6,
        },
    )
    if day == today:
        _dd(cur, day, "vo2max_submax", 43.0, {"r2": 0.82, "speed_kmh": 8.1})


def _seed_manual(cur) -> None:
    # "Today's" logs are anchored to the user-local day, not a UTC `now() - Nh`
    # offset — the latter can cross local midnight and land on yesterday's local
    # date, silently dropping the caffeine/meditation/fasting keys from
    # logs_summary (a snapshot flake for any run in the post-midnight window).
    caffeine_ts = _recent_today(hours=3)
    med_ts = _recent_today(hours=2)
    fast_ts = _recent_today(hours=5)
    cur.execute(
        "INSERT INTO manual_entry (user_id, kind, ts, amount, unit) "
        "VALUES (%s, 'caffeine', %s, 80, 'mg')",
        (SENTINEL_USER_ID, caffeine_ts),
    )
    cur.execute(
        "INSERT INTO manual_entry (user_id, kind, ts, end_ts, name, amount, unit) "
        "VALUES (%s, 'meditation', %s, %s, 'mindfulness', 10, 'min')",
        (SENTINEL_USER_ID, med_ts, med_ts + timedelta(minutes=10)),
    )
    cur.execute(
        "INSERT INTO manual_entry (user_id, kind, ts, name, amount, unit) "
        "VALUES (%s, 'exercise', now() - interval '1 day', 'strength', 45, 'min')",
        (SENTINEL_USER_ID,),
    )
    cur.execute(
        "INSERT INTO manual_entry (user_id, kind, ts) VALUES (%s, 'fasting', %s)",
        (SENTINEL_USER_ID, fast_ts),
    )


def _recent_today(hours: float) -> datetime:
    """A tz-aware instant ~``hours`` before now, clamped to stay on today's user-local
    date, so ``(ts AT TIME ZONE USER_TZ)::date == user_today()`` no matter when the
    test runs (including just after local midnight)."""
    now_local = datetime.now(tz=USER_TZ)
    floor = datetime.combine(now_local.date(), time(0, 1), tzinfo=USER_TZ)
    return max(now_local - timedelta(hours=hours), floor)


def _seed_illness(cur, today: date) -> None:
    cur.execute(
        "INSERT INTO illness_flag (user_id, date, severity, rr_delta_bpm, temp_delta_c, "
        "sustained, research_note_ids) VALUES (%s,%s,'moderate',2.4,0.35,false,%s) "
        "ON CONFLICT (user_id, date) DO NOTHING",
        (SENTINEL_USER_ID, today, ["respiratory_rate_normal", "skin_temp_signals"]),
    )


def _seed_recommendation(cur, today: date) -> None:
    cur.execute(
        "INSERT INTO recommendation (user_id, date, rank, action, rationale, expected_effect, "
        "category, evidence_grade, research_note_ids, signal_source) VALUES "
        "(%s,%s,1,'Sleep earlier tonight','Debt is 120 min','Lower debt','sleep',3,%s,"
        "'sleep_debt') ON CONFLICT (user_id, date, rank) DO NOTHING",
        (SENTINEL_USER_ID, today, ["sleep_need_debt"]),
    )


def _seed_finding(cur) -> None:
    cur.execute(
        "INSERT INTO finding (user_id, kind, description, metric_a, metric_b, lag_days, "
        "effect_size, effect_metric, p_value, q_value, n_samples, significant, "
        "research_note_ids) "
        "VALUES (%s,'pairwise_lag','Caffeine ↔ sleep','caffeine','sleep_health_score_4dim',0,"
        "-0.42,'rho',0.01,0.03,24,true,%s) ON CONFLICT DO NOTHING",
        (SENTINEL_USER_ID, ["caffeine_sleep"]),
    )


def _seed_gps(cur) -> None:
    start = datetime.now(tz=UTC) - timedelta(hours=3)
    end = start + timedelta(minutes=30)
    cur.execute(
        "INSERT INTO gps_track (user_id,start_ts,end_ts,source,distance_m,duration_s,avg_hr,"
        "ele_gain_m,vo2max_submax,r2) "
        "VALUES (%s,%s,%s,'phone',4200,1800,135,60,43.0,0.82) RETURNING id",
        (SENTINEL_USER_ID, start, end),
    )
    track_id = cur.fetchone()[0]
    pts = [
        (
            SENTINEL_USER_ID,
            track_id,
            start + timedelta(seconds=30 * i),
            12.9 + i * 1e-4,
            77.6 + i * 1e-4,
            10.0 + i,
        )
        for i in range(20)
    ]
    cur.executemany(
        "INSERT INTO gps_point (user_id, track_id, ts, lat, lng, ele_m) "
        "VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING",
        pts,
    )
