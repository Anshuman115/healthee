"""History markers preserve owner-local days and exclude unrelated log kinds."""

import json
from datetime import datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from tests.contracts.shape import assert_conforms

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today

_SNAPSHOT = Path(__file__).resolve().parents[4] / "packages/contracts/snapshots/history_logs.json"


def test_history_log_markers_are_bounded_and_use_local_days(seeded_client: tuple) -> None:
    client, headers = seeded_client
    today = user_today(SENTINEL_TZ)
    midnight = datetime.combine(today, time.min, ZoneInfo(SENTINEL_TZ))
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.executemany(
            "INSERT INTO manual_entry (user_id, kind, ts, amount, unit) "
            "VALUES (%s, 'alcohol', %s, 1, 'drinks')",
            [
                (SENTINEL_USER_ID, midnight - timedelta(minutes=1)),
                (SENTINEL_USER_ID, midnight + timedelta(minutes=1)),
            ],
        )
    response = client.get("/api/history/logs", params={"days": 1}, headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert_conforms(data, json.loads(_SNAPSHOT.read_text()))
    assert all(marker["day"] == today.isoformat() for marker in data["markers"])
    alcohol = [marker for marker in data["markers"] if marker["kind"] == "alcohol"]
    assert alcohol == [{"day": today.isoformat(), "kind": "alcohol", "count": 1}]
    assert "fasting" not in {marker["kind"] for marker in data["markers"]}
    for days in [0, 1826]:
        assert (
            client.get("/api/history/logs", params={"days": days}, headers=headers).status_code
            == 422
        )
    assert client.get("/api/history/logs").status_code == 401
