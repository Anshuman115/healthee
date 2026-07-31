"""HTTP behaviour of the programs endpoints (WP-C4).

``test_contracts`` pins the response SHAPE; this pins what the endpoints DO. Three
properties matter most on the wire and none of them is about a happy path:

* **the ladder reads back as its own history** — a rung that timed out unmet is on the
  wire as ``expired`` with an ``unmet_timed_out`` outcome, beside the ``deload`` rung
  that answered it. Legacy would have published both as "completed";
* **there is no advance endpoint and no target anywhere.** Advancement is a nightly
  consequence of what the rungs did, and a rung's number is recalibrated server-side;
* **another owner's ladder does not resolve.** 404, not 403 — a 403 for the ids that
  exist would confirm another tenant's ids to anyone who asked.

Auto-skips without a reachable TimescaleDB (the contract bed's policy).
"""

from __future__ import annotations

from typing import Any

import pytest
from tests.contracts.seed_owner_b import OWNER_B, seed_owner_b

from healthee.challenges import ladder
from healthee.core.db import tenant_transaction

pytestmark = pytest.mark.integration


def _programs(client: Any, headers: dict) -> dict:
    resp = client.get("/api/programs", headers=headers)
    assert resp.status_code == 200, resp.text[:200]
    return resp.json()


def test_the_ladder_reads_back_as_the_story_it_actually_was(seeded_client: tuple) -> None:
    """met → unmet_timed_out → the deload that answered it → a rung not yet reached.

    The whole WP in one payload. Each rung carries its own frozen outcome, so a client
    renders the history rather than a progress bar that has quietly forgotten a failure.
    """
    client, headers = seeded_client
    active = _programs(client, headers)["active"]
    assert active is not None
    told = [
        (rung["kind"], rung["status"], (rung["outcome"] or {}).get("status"))
        for rung in active["rungs"]
    ]
    assert told == [
        ("standard", "completed", "met"),
        ("standard", "expired", "unmet_timed_out"),
        ("deload", "active", None),
        ("standard", "locked", None),
    ]
    assert (active["rung_count"], active["settled_rungs"]) == (4, 2)
    assert active["hold_reason"] is None  # nothing is paused, so nothing claims to be


def test_a_rung_carries_progress_or_an_outcome_and_never_invents_either(
    seeded_client: tuple,
) -> None:
    """A locked rung has neither, and both keys are still present and null.

    "Not reached yet" is a real state and it must not render as 0 % — that is the same
    distinction ``metrics.spec`` raises for an untrackable metric rather than scoring it
    zero forever (standards §Errors: no data and failed are different states).
    """
    client, headers = seeded_client
    rungs = _programs(client, headers)["active"]["rungs"]
    locked, live = rungs[3], rungs[2]
    assert (locked["progress"], locked["outcome"]) == (None, None)
    assert live["outcome"] is None and live["progress"]["cadence"] == "daily"
    # A live rung is an ordinary active challenge, so it carries the same pending
    # recalibration the challenges feed shows — one function, two surfaces.
    assert "adaptation" in live["progress"]


def test_the_feed_states_the_one_program_rule(seeded_client: tuple) -> None:
    """``active`` is an object or null, never a list — one ladder per owner is the rule."""
    client, headers = seeded_client
    feed = _programs(client, headers)
    assert isinstance(feed["active"], dict)
    assert feed["max_active_programs"] == ladder.MAX_ACTIVE_PROGRAMS
    assert feed["suggested"] == [] and feed["recent"] == []


def test_adopting_an_already_running_ladder_is_a_conflict(seeded_client: tuple) -> None:
    """A second adopt would restart a ladder mid-climb, re-anchoring its rung's baseline."""
    client, headers = seeded_client
    program_id = _programs(client, headers)["active"]["id"]
    resp = client.post(f"/api/programs/{program_id}/adopt", headers=headers)
    assert resp.status_code == 409
    assert resp.json()["detail"]["reason"] == "not_suggested"


def test_an_unknown_program_is_404(seeded_client: tuple) -> None:
    client, headers = seeded_client
    resp = client.post("/api/programs/987654/abandon", headers=headers)
    assert resp.status_code == 404
    assert resp.json()["detail"]["reason"] == "not_found"


def test_abandoning_freezes_the_live_rung_and_returns_the_stored_ladder(
    seeded_client: tuple,
) -> None:
    """Giving up is a result: the running rung is closed and its outcome written.

    The response is the STORED ladder, so a client renders what landed rather than an
    echo of the request — and a second abandon is a conflict, not a silent success.
    """
    client, headers = seeded_client
    program_id = _programs(client, headers)["active"]["id"]
    resp = client.post(f"/api/programs/{program_id}/abandon", headers=headers)
    assert resp.status_code == 200
    program = resp.json()["program"]
    assert program["status"] == "abandoned"
    assert program["completed_at"] is None  # abandoned is not completed, ever
    assert program["ended_reason"] and program["ended_at"]
    assert [r["status"] for r in program["rungs"]] == [
        "completed",
        "expired",
        "abandoned",
        "locked",
    ]
    assert program["rungs"][2]["outcome"]["status"] == "abandoned"
    again = client.post(f"/api/programs/{program_id}/abandon", headers=headers)
    assert again.status_code == 409


def test_the_program_feed_is_a_pure_read(seeded_client: tuple) -> None:
    """Two identical GETs return identical payloads — a read never advances a ladder."""
    client, headers = seeded_client
    assert _programs(client, headers) == _programs(client, headers)


def test_another_owners_ladder_does_not_resolve(seeded_client: tuple) -> None:
    """404 for every verb, and B's ladder never appears on A's feed (MULTI_USER §10).

    A 404 that became a 409 for the ids that exist would confirm another tenant's ids to
    anyone willing to enumerate them. Owner B here owns a SUGGESTED program — the state
    that would otherwise be adoptable — so the test proves the scope rather than relying
    on the status check to refuse first.
    """
    client, headers = seeded_client
    seed_owner_b()
    with tenant_transaction(OWNER_B) as cur:
        cur.execute(
            "INSERT INTO program (user_id, title, why, goal, goal_metric, category, weeks, "
            "  status) VALUES (%s,'B only','w','g','steps_total','activity',4,'suggested') "
            "RETURNING id",
            (OWNER_B,),
        )
        row = cur.fetchone()
        assert row is not None
        b_id = int(row[0])
    for verb in ("adopt", "abandon"):
        resp = client.post(f"/api/programs/{b_id}/{verb}", headers=headers)
        assert resp.status_code == 404, f"{verb}: {resp.status_code}"
        assert resp.json()["detail"]["reason"] == "not_found"
    assert _programs(client, headers)["suggested"] == []


def test_the_program_endpoints_require_authentication(seeded_client: tuple) -> None:
    """Every program surface is behind the owner dependency, with no gaps.

    Premium gating (6.6) is NOT built — these are reachable by any authenticated owner,
    exactly like every other AI surface today. Authentication is the line that does
    exist, so it is the line that gets tested.
    """
    client, _ = seeded_client
    for method, path in (
        ("GET", "/api/programs"),
        ("POST", "/api/programs/1/adopt"),
        ("POST", "/api/programs/1/abandon"),
    ):
        assert client.request(method, path).status_code == 401, path


def test_a_program_write_takes_no_body(seeded_client: tuple) -> None:
    """There is nowhere to put a target, so a client cannot dictate one (§5.2's rule).

    The rung's number comes from ``rung.recalibrated_target`` against the owner's own
    current baseline; a body offering 50,000 changes nothing because nothing reads it.
    """
    client, headers = seeded_client
    program_id = _programs(client, headers)["active"]["id"]
    resp = client.post(
        f"/api/programs/{program_id}/abandon", headers=headers, json={"target_value": 50000}
    )
    assert resp.status_code == 200
    assert resp.json()["program"]["rungs"][2]["target_value"] == 8900.0
