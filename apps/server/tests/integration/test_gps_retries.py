"""A lost GPS response can be retried without creating a second workout."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from pydantic import ValidationError

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.read.gps import GpsTrackIn, ingest_gps_track


def _request() -> GpsTrackIn:
    start = datetime(2026, 6, 20, tzinfo=UTC)
    return GpsTrackIn(
        client_id=uuid4(),
        start_iso=start.isoformat(),
        end_iso=(start + timedelta(seconds=30)).isoformat(),
        points=[[start.timestamp() + i, 12.0, 77.0, None] for i in range(10)],
    )


@pytest.mark.integration
def test_same_client_recording_is_stored_once() -> None:
    migrate.apply_migrations()
    req = _request()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        first = ingest_gps_track(cur, SENTINEL_USER_ID, SENTINEL_TZ, req)
        again = ingest_gps_track(cur, SENTINEL_USER_ID, SENTINEL_TZ, req)
        assert first["ok"] and again["ok"]
        assert first["track_id"] == again["track_id"] == str(req.client_id)
        assert again["points"] == 10
        cur.execute(
            "SELECT count(*) FROM gps_track WHERE user_id = %s AND id = %s",
            (SENTINEL_USER_ID, req.client_id),
        )
        assert cur.fetchone() == (1,)
        changed = req.model_copy(update={"end_iso": "2026-06-20T00:01:00+00:00"})
        assert ingest_gps_track(cur, SENTINEL_USER_ID, SENTINEL_TZ, changed)["ok"] is False


@pytest.mark.parametrize(
    "point", [[0, 12, 77], [1781913600, 91, 77], [1781913600, 12, float("nan")], [None, 12, 77]]
)
def test_invalid_points_are_rejected(point: list) -> None:
    body = _request().model_dump()
    body["points"] = [point]
    with pytest.raises(ValidationError):
        GpsTrackIn.model_validate(body)


def test_nonmonotonic_points_are_rejected() -> None:
    body = _request().model_dump()
    body["points"] = list(reversed(body["points"]))
    with pytest.raises(ValidationError):
        GpsTrackIn.model_validate(body)
