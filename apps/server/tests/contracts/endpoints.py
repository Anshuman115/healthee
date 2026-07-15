"""The read endpoints exercised by the contract bed, and a helper that calls every
one against a seeded ``TestClient`` (resolving the two dynamic ids — a workout
start and a GPS track id — from prior responses)."""

from __future__ import annotations

from typing import Any

# name → (method, path, params, json-body). Names are the snapshot filenames.
STATIC_ENDPOINTS: list[tuple[str, str, str, dict | None, dict | None]] = [
    ("today", "GET", "/api/today", None, None),
    ("sleep", "GET", "/api/sleep", {"days": 30}, None),
    ("sleep_health_score", "GET", "/api/sleep/health_score", {"days": 30}, None),
    ("sleep_consistency", "GET", "/api/sleep/consistency", {"days": 28}, None),
    ("activity", "GET", "/api/activity", None, None),
    ("history", "GET", "/api/history", {"metric": "steps_total", "days": 30}, None),
    ("profile", "GET", "/api/profile", None, None),
    ("log_recent", "GET", "/api/log/recent", {"days": 7}, None),
    ("gps_list", "GET", "/api/workout/gps", None, None),
    ("log_post", "POST", "/api/log", None, {"type": "caffeine", "amount": 50, "unit": "mg"}),
]


def call_all(client: Any, headers: dict) -> dict[str, Any]:
    """Return {endpoint_name: response_json} for every read endpoint (200s asserted)."""
    out: dict[str, Any] = {}
    for name, method, path, params, body in STATIC_ENDPOINTS:
        resp = client.request(method, path, params=params, json=body, headers=headers)
        assert resp.status_code == 200, f"{name}: {resp.status_code} {resp.text[:200]}"
        out[name] = resp.json()
    out["workout"] = _workout(client, headers, out["activity"])
    out["gps_detail"] = _gps_detail(client, headers, out["gps_list"])
    return out


def _workout(client: Any, headers: dict, activity: dict) -> Any:
    workouts = activity.get("workouts") or []
    if not workouts:
        return None
    resp = client.get(
        "/api/activity/workout", params={"start": workouts[0]["start_iso"]}, headers=headers
    )
    assert resp.status_code == 200, f"workout: {resp.status_code} {resp.text[:200]}"
    return resp.json()


def _gps_detail(client: Any, headers: dict, gps_list: dict) -> Any:
    tracks = gps_list.get("tracks") or []
    if not tracks:
        return None
    resp = client.get(f"/api/workout/gps/{tracks[0]['track_id']}", headers=headers)
    assert resp.status_code == 200, f"gps_detail: {resp.status_code} {resp.text[:200]}"
    return resp.json()
