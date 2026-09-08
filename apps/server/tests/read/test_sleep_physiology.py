"""The night-physiology join reads exactly the metrics it reports (`PERF_AUDIT.md` A1).

The predicate that made `/api/sleep` affordable — `s.metric = ANY(…)` — introduced one
new way for this endpoint to be silently wrong, and it is the endpoint's own worst shape:
a metric named in a `CASE WHEN s.metric='…'` expression but MISSING from
`PHYSIOLOGY_METRICS` is never read, so its average is NULL, and NULL on this payload
already means *"the strap did not measure it"*. A measured night would report an
unmeasured one. Nothing would raise, and the wire would look healthy.

Two guards, and they fail for different reasons on purpose:

* `test_the_predicate_names_every_metric_the_select_reports` DERIVES the metric names
  back out of the SQL text and compares them to the tuple. A list of names written by
  hand cannot cover what nobody thought to add (`HOW_WE_VERIFY.md` section 4); this one
  cannot go stale, because it reads the query the code actually issues.
* `test_every_reported_physiology_metric_survives_the_predicate` seeds one night of all
  three metrics and asserts three non-null numbers off `sleep_page`. That is the property
  the owner sees, and it fails even if someone rewrites the SQL past the derived check.
"""

from __future__ import annotations

import re
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.read.sleep_page import _PHYSIOLOGY_SQL, PHYSIOLOGY_METRICS, sleep_page

pytestmark = pytest.mark.integration

ZONE = ZoneInfo(SENTINEL_TZ)

# What each metric's average must come back as, hand-picked so a value from the wrong
# metric could not be mistaken for the right one.
_SEEDED = {"spo2": 97.0, "respiratory_rate": 14.0, "skin_temp_c": 33.0}
_PAYLOAD_KEY = {
    "spo2": "spo2_avg",
    "respiratory_rate": "respiratory_rate",
    "skin_temp_c": "skin_temp_c",
}


def test_the_predicate_names_every_metric_the_select_reports() -> None:
    """Every `CASE WHEN s.metric='X'` in the query is in `PHYSIOLOGY_METRICS`, and back.

    Read off the SQL the code issues, not off a list beside it — the two agreeing is the
    whole property, so asking one of them about itself would prove nothing.
    """
    in_select = set(re.findall(r"s\.metric='([a-z0-9_]+)'", _PHYSIOLOGY_SQL))

    assert in_select, "no CASE metric names found — the regex has gone stale, not the code"
    assert in_select == set(PHYSIOLOGY_METRICS), (
        "the metrics the SELECT reports and the metrics the WHERE reads have drifted: "
        f"reported {sorted(in_select)}, read {sorted(PHYSIOLOGY_METRICS)}. A metric on "
        "only the SELECT side ships NULL, which this payload means as 'not measured'."
    )
    assert "s.metric = ANY(" in _PHYSIOLOGY_SQL, (
        "the metric predicate is gone — the join is back to reading every metric in "
        "every night window (PERF_AUDIT.md A1: 15,363 ms at days=365)"
    )


def _seed_one_night(cur) -> date:
    """One main session last night, with all three physiology metrics inside it."""
    cur.execute("DELETE FROM sample")
    cur.execute("DELETE FROM sleep_session")
    wake = user_today(SENTINEL_TZ)
    start = datetime.combine(wake - timedelta(days=1), time(23, 0), tzinfo=ZONE).astimezone(UTC)
    end = datetime.combine(wake, time(6, 30), tzinfo=ZONE).astimezone(UTC)
    cur.execute(
        "INSERT INTO sleep_session (user_id, start_ts, end_ts, kind, rem_min, light_min, "
        "deep_min, wake_min) VALUES (%s, %s, %s, 'main', 90, 200, 90, 20)",
        (SENTINEL_USER_ID, start, end),
    )
    for metric, value in _SEEDED.items():
        for i in range(5):
            cur.execute(
                "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s)",
                (SENTINEL_USER_ID, start + timedelta(minutes=10 * i), metric, value),
            )
    # A metric the predicate must EXCLUDE, inside the same window and at a value that
    # would be obvious if it leaked into any of the three averages.
    for i in range(5):
        cur.execute(
            "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, 'hr', 58)",
            (SENTINEL_USER_ID, start + timedelta(minutes=10 * i)),
        )
    return wake


def test_every_reported_physiology_metric_survives_the_predicate() -> None:
    """All three come back with their seeded value — none nulled by the narrowed read."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        wake = _seed_one_night(cur)
        page = sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ, days=7, day=wake)

    nights = {night["date"]: night for night in page["nights"]}
    night = nights[wake.isoformat()]
    for metric, expected in _SEEDED.items():
        key = _PAYLOAD_KEY[metric]
        assert night[key] == pytest.approx(expected), (
            f"{metric} came back as {night[key]!r}, not {expected}. A metric dropped "
            f"from the read ships NULL, which this payload means as 'not measured'."
        )
