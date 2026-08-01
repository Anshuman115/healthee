"""The seeded owner every biological-age freshness test shares.

Extracted when ``test_biological_age_freshness`` grew past the 400-line gate and the
per-term rule earned its own module: the fixture, the hand-derived expected years, and
the two assertion helpers are one bed used by two files, and copying them would be the
second occurrence standards §Duplication bans — with the specific risk that two copies
of ``_seed_owner`` could drift and quietly test different owners.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

# ── the fixture, chosen so every expected number is hand-derivable ────────────
#
# Identical inputs to `test_biological_age_math`'s composed case, so the two files pin
# the same arithmetic from opposite sides: that one through a stub, this one through a
# real database and the real withhold gate.
CHRONO_AGE = 40
VO2MAX = 41.5  # ml/kg/min — vs the note's 38.0 median for a 40 y male
TST_MIN = 360.0  # 6.0 h/night across the 14-night window

# Hand-derived from [[biological_age_estimate]] (see test_biological_age_math for the
# full working): fitness −1.8054, sleep +0.6473 → ΔAge −1.1581.
FITNESS_YEARS = -1.8
SLEEP_YEARS = 0.6
BIO_AGE = 38.8

# median 56, MAD 4 → inside every gate: these seven days DERIVE.
CALM = [50.0, 52.0, 54.0, 56.0, 58.0, 60.0, 62.0]
# median 56, MAD 12 → above the note's 8 bpm ceiling: this week is WITHHELD. Seven days
# on purpose — the gate reads a 7-day window, so a shorter noisy run would leave calm
# days in it and the MAD would be of the mixture (the same trap `test_vo2max_freshness`
# documents).
NOISY = [40.0, 44.0, 47.0, 56.0, 65.0, 68.0, 72.0]


def reset(cur) -> None:
    for table in ("derived_daily", "weight_log", "profile"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def dd(cur, day: date, metric: str, value: float, flags: dict | None = None) -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, %s, %s, %s::jsonb) ON CONFLICT (user_id, day, metric) DO UPDATE "
        "SET value = EXCLUDED.value, flags = EXCLUDED.flags",
        (SENTINEL_USER_ID, day, metric, value, json.dumps(flags or {})),
    )


def seed_owner(cur, today: date) -> None:
    """A profile at exactly ``CHRONO_AGE``, plus the sleep-duration term's input.

    It deliberately seeds NO ``sleep_regularity_index`` row: since #86 the estimate has
    no regularity term, and a bed that kept feeding one would let a re-added term look
    fed rather than fail.

    The dob is anchored to the owner's OWN today (not the process date) and set to
    Jan 1, so the chronological age is 40 on every run date — ``(m, d) < (1, 1)`` is
    false for every day of the year.
    """
    cur.execute(
        "INSERT INTO profile (user_id, height_cm, sex, dob) VALUES (%s, 175, 'male', %s)",
        (SENTINEL_USER_ID, date(today.year - CHRONO_AGE, 1, 1)),
    )
    cur.execute(
        # Yesterday, not a month ago: since #85 a weight older than
        # `freshness.WEIGHT_MAX_AGE_DAYS` withholds the VO2max and therefore the whole
        # composite, and this bed exists to exercise the TERM logic, not that gate.
        "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, now() - interval '1 day', 72)",
        (SENTINEL_USER_ID,),
    )
    for n in range(14):
        dd(cur, today - timedelta(days=n), "sleep_health_score_4dim", 2.0, {"tst_min": TST_MIN})


def rhr(cur, day: date, values: list[float]) -> None:
    """One ``rhr_daily`` row per day of the 7-day window ENDING on ``day``."""
    for k, value in enumerate(values):
        dd(cur, day - timedelta(days=len(values) - 1 - k), "rhr_daily", value)


def terms(result: dict) -> dict[str, dict]:
    return {c["term"]: c for c in result["contributions"]}


def absent(result: dict) -> dict[str, str]:
    """The withheld terms as ``{term: reason}`` — the assertion every case here makes."""
    withheld = result["withheld"]
    return {} if withheld is None else {t["term"]: t["reason"] for t in withheld["terms"]}


def seed_nights(cur, today: date, n: int) -> None:
    """``n`` consecutive main-sleep nights ending on ``today`` — a COMPLETE SRI window
    when ``n >= 6``, which is what ``sri_withhold_reason_for_day`` re-checks.

    Real ``sleep_session`` rows with a hypnogram, not a hand-written SRI: the gate reads
    the minute grid, so a fixture that seeded the derived row instead could not tell a
    complete week from an empty one — and a fixture sharing the code's assumption cannot
    fail (the lesson from the dob/baseline timezone bugs).
    """
    zone = ZoneInfo(SENTINEL_TZ)
    for k in range(n):
        wake = today - timedelta(days=k)
        start = datetime.combine(wake - timedelta(days=1), time(23, 0), tzinfo=zone)
        end = datetime.combine(wake, time(6, 30), tzinfo=zone)
        stages = [[int(start.timestamp() * 1000), int(end.timestamp() * 1000), 4]]
        cur.execute(
            "INSERT INTO sleep_session (user_id, start_ts, end_ts, kind, rem_min, light_min, "
            "deep_min, wake_min, stages) VALUES (%s,%s,%s,'main',90,200,90,20,%s) "
            "ON CONFLICT (user_id, start_ts) DO NOTHING",
            (SENTINEL_USER_ID, start.astimezone(UTC), end.astimezone(UTC), json.dumps(stages)),
        )
