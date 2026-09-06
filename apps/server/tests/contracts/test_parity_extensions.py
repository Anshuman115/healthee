"""New parity routes roundtrip real seeded rows behind their HTTP guards."""

import json
from pathlib import Path

from tests.contracts.shape import assert_conforms

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID

_SNAPSHOTS = Path(__file__).resolve().parents[4] / "packages" / "contracts" / "snapshots"


def test_account_identity_is_authenticated(seeded_client: tuple) -> None:
    client, headers = seeded_client
    response = client.get("/api/account", headers=headers)
    assert response.json() == {"user_id": str(SENTINEL_USER_ID), "timezone": "Asia/Kolkata"}
    assert client.get("/api/account").status_code == 401


def test_recommendation_history_and_adoption(seeded_client: tuple) -> None:
    client, headers = seeded_client
    response = client.get("/api/recommendations", params={"days": 180}, headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert_conforms(data, json.loads((_SNAPSHOTS / "recommendations.json").read_text()))
    rec = data["recommendations"][0]
    for action, adopted in [("adopt", True), ("dismiss", False)]:
        result = client.post(f"/api/recommendations/{rec['id']}/{action}", headers=headers)
        assert result.json() == {"ok": True, "id": rec["id"], "adopted": adopted}
        rows = client.get("/api/recommendations", params={"days": 180}, headers=headers).json()
        assert rows["recommendations"][0]["adopted"] is adopted
    assert client.post("/api/recommendations/99999999/adopt", headers=headers).status_code == 404


def test_weight_and_flag_history_return_actual_observations(seeded_client: tuple) -> None:
    client, headers = seeded_client
    for metric in ["weight_kg", "moderate_min", "vigorous_min"]:
        response = client.get(
            "/api/history", params={"metric": metric, "days": 365}, headers=headers
        )
        assert response.status_code == 200
        assert response.json()["series"], metric


def test_workout_trimp_uses_profile_sex_and_withholds_unknown(seeded_client: tuple) -> None:
    client, headers = seeded_client
    start = client.get("/api/activity", headers=headers).json()["workouts"][0]["start_iso"]
    male = client.get("/api/activity/workout", params={"start": start}, headers=headers).json()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("UPDATE profile SET sex = %s WHERE user_id = %s", ("female", SENTINEL_USER_ID))
    female = client.get("/api/activity/workout", params={"start": start}, headers=headers).json()
    assert female["metrics"]["trimp"] != male["metrics"]["trimp"]
    client.patch("/api/profile", headers=headers, json={"sex": None})
    unknown = client.get("/api/activity/workout", params={"start": start}, headers=headers).json()
    assert "trimp" not in unknown["metrics"]
