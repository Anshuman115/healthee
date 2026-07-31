"""HTTP behaviour of the challenges endpoints (WP-C2).

``test_contracts`` pins the response SHAPE; this pins what the endpoints DO — the
statuses a refusal comes back as, that a GET never writes, and the two properties
that matter most on the wire:

* **an adapt request carries no target.** §5.2's server-authoritative rule is
  structural here: there is no body to put one in, and a body offering one changes
  nothing;
* **another owner's challenge does not resolve.** 404, not 403 — a 403 for the ids
  that exist would confirm another tenant's ids to anyone who asked.

Auto-skips without a reachable TimescaleDB (the contract bed's policy).
"""

from __future__ import annotations

from typing import Any

import pytest
from tests.contracts.seed_owner_b import OWNER_B, seed_owner_b

from healthee.challenges import lifecycle
from healthee.core.db import tenant_transaction

pytestmark = pytest.mark.integration


def _feed(client: Any, headers: dict) -> dict:
    resp = client.get("/api/challenges", headers=headers)
    assert resp.status_code == 200, resp.text[:200]
    return resp.json()


def _live_challenge(client: Any, headers: dict) -> dict:
    """The bed's one STANDALONE active challenge, named by intent rather than by index.

    The active list also carries the seeded program's running rung (WP-C4), and these
    tests are about the standalone lifecycle. Picking by `program_id` says which one
    they mean; `[0]` said "whichever the feed put first", which stopped being one
    challenge the moment a ladder existed.
    """
    standalone = [c for c in _feed(client, headers)["active"] if c["program_id"] is None]
    assert len(standalone) == 1, f"expected one standalone active challenge, got {standalone}"
    return standalone[0]


def test_the_feed_separates_the_three_states(seeded_client: tuple) -> None:
    """Suggestions, live progress, and what recently ended are three different lists."""
    client, headers = seeded_client
    feed = _feed(client, headers)
    assert len(feed["suggested"]) == 1
    assert feed["max_active"] == lifecycle.MAX_ACTIVE
    standalone = [c for c in feed["active"] if c["program_id"] is None]
    assert len(standalone) == 1
    assert standalone[0]["progress"]["target"] == 9000.0
    assert [c["status"] for c in feed["recent"] if c["program_id"] is None] == ["completed"]
    # The ladder's settled rungs are finished challenges and belong on this list too —
    # including the one that ran out UNMET, which is `expired` and NOT `completed`
    # (CHALLENGES.md §2.3, the whole point of the WP-C4 vocabulary).
    assert sorted(c["status"] for c in feed["recent"] if c["program_id"]) == [
        "completed",
        "expired",
    ]


def test_a_live_program_rung_is_a_live_challenge_on_this_feed(seeded_client: tuple) -> None:
    """WP-C4: the ACTIVE list carries the ladder's running rung too, and says it is one.

    A rung is a commitment the owner is keeping right now, so hiding it from the
    challenges feed would understate what they are carrying — and it is counted against
    ``MAX_ACTIVE`` for exactly that reason (``challenges/programs.py``). ``program_id``
    and ``kind`` are what let a client badge it as a rung, and as a DELOAD rung: the
    copy deliberately does not say so, because no new prose is authored on that path.
    """
    client, headers = seeded_client
    rungs = [c for c in _feed(client, headers)["active"] if c["program_id"] is not None]
    assert len(rungs) == 1
    assert (rungs[0]["kind"], rungs[0]["rung_index"]) == ("deload", 2)
    assert rungs[0]["progress"]["cadence"] == "daily"


def test_adopting_freezes_a_baseline_and_starts_the_window(seeded_client: tuple) -> None:
    """The response carries the STORED challenge — the baseline the server computed.

    The client renders "you're on" from this, so it must be what actually landed, not
    an echo of what was asked for.
    """
    client, headers = seeded_client
    suggestion = _feed(client, headers)["suggested"][0]
    resp = client.post(f"/api/challenges/{suggestion['id']}/adopt", headers=headers)
    assert resp.status_code == 200
    adopted = resp.json()["challenge"]
    assert adopted["status"] == "active"
    # RECOMPUTED at adopt from the seed's flat 30-day `active_calories` series, not the
    # 8,200 the seeded row carried — which is the property this test exists for.
    assert adopted["baseline_value"] == 620.0
    assert adopted["adopted_at"] is not None and adopted["ends_at"] is not None


def test_adopting_twice_is_a_conflict_not_a_silent_success(seeded_client: tuple) -> None:
    """A second adopt would re-anchor the baseline, so it is refused — and says why."""
    client, headers = seeded_client
    suggestion = _feed(client, headers)["suggested"][0]
    assert (
        client.post(f"/api/challenges/{suggestion['id']}/adopt", headers=headers).status_code == 200
    )
    again = client.post(f"/api/challenges/{suggestion['id']}/adopt", headers=headers)
    assert again.status_code == 409
    assert again.json()["detail"]["reason"] == "not_suggested"


def test_an_unknown_challenge_is_404(seeded_client: tuple) -> None:
    client, headers = seeded_client
    resp = client.post("/api/challenges/987654/adopt", headers=headers)
    assert resp.status_code == 404
    assert resp.json()["detail"]["reason"] == "not_found"


def test_abandoning_returns_the_stored_row(seeded_client: tuple) -> None:
    client, headers = seeded_client
    active = _live_challenge(client, headers)
    resp = client.post(f"/api/challenges/{active['id']}/abandon", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["challenge"]["status"] == "abandoned"
    assert (
        client.post(f"/api/challenges/{active['id']}/abandon", headers=headers).status_code == 409
    )


def test_adapt_takes_no_target_from_the_client(seeded_client: tuple) -> None:
    """§5.2: a client may REQUEST an adaptation; it can never dictate the number.

    The seed's flat 8,200-step week is inside the productive band against a 9,000
    target, so nothing is due — and a body screaming for 50,000 changes neither the
    verdict nor the stored target. The endpoint has nowhere to put a client's number.
    """
    client, headers = seeded_client
    active = _live_challenge(client, headers)
    resp = client.post(
        f"/api/challenges/{active['id']}/adapt",
        headers=headers,
        json={"target_value": 50000, "suggested": 50000},
    )
    assert resp.status_code == 409
    assert resp.json()["detail"]["reason"] == "no_adaptation"
    assert _live_challenge(client, headers)["target_value"] == 9000.0


def test_the_ledger_returns_the_frozen_outcome_with_its_caveats(seeded_client: tuple) -> None:
    """Every honesty field travels with the number — that is the point of §7.1.

    A client that could receive `improvement_pct` without `data_confidence`, or a
    co-occurring delta without the concurrency count, could render a claim we do not
    make.
    """
    client, headers = seeded_client
    resp = client.get("/api/challenges/outcomes", headers=headers)
    assert resp.status_code == 200
    outcome = resp.json()["outcomes"][0]
    assert outcome["status"] == "met"
    assert outcome["data_confidence"] == "ok"
    assert outcome["co_occurring"]["attribution"] == "none"
    assert outcome["co_occurring"]["concurrent_challenges"] == 1
    assert outcome["confounds"]["illness_days"] == 1


def test_the_feed_is_a_pure_read(seeded_client: tuple) -> None:
    """The seeded active challenge has run its window out; GET must not close it."""
    client, headers = seeded_client
    before = _live_challenge(client, headers)
    after = _live_challenge(client, headers)
    assert (before["status"], after["status"]) == ("active", "active")


def test_another_owners_challenge_does_not_resolve(seeded_client: tuple) -> None:
    """404 for every verb — B's ids must not be distinguishable from ids that never were.

    Owner B adopts their own challenge; A (the sentinel, who the contract bed's token
    resolves to) must be unable to touch it, and must not learn that it exists.
    """
    client, headers = seeded_client
    seed_owner_b()
    with tenant_transaction(OWNER_B) as cur:
        cur.execute(
            "INSERT INTO challenge (user_id, title, why, category, metric, comparator, "
            "  target_value, cadence, window_days, status) "
            "VALUES (%s,'B only','w','activity','steps_total','>=',9000,'daily',7,'suggested') "
            "RETURNING id",
            (OWNER_B,),
        )
        row = cur.fetchone()
        assert row is not None
        b_id = int(row[0])
    for verb in ("adopt", "abandon", "adapt"):
        resp = client.post(f"/api/challenges/{b_id}/{verb}", headers=headers)
        assert resp.status_code == 404, f"{verb}: {resp.status_code}"
    assert all(c["title"] != "B only" for c in _feed(client, headers)["suggested"])


def test_the_endpoints_require_authentication(seeded_client: tuple) -> None:
    """Every challenge surface is behind the owner dependency, with no gaps.

    Premium gating (6.6) is NOT built — these are reachable by any authenticated
    owner, exactly like every other AI surface today. Authentication is the line that
    does exist, so it is the line that gets tested.
    """
    client, _ = seeded_client
    for method, path in (
        ("GET", "/api/challenges"),
        ("GET", "/api/challenges/outcomes"),
        ("POST", "/api/challenges/1/adopt"),
        ("POST", "/api/challenges/1/abandon"),
        ("POST", "/api/challenges/1/adapt"),
    ):
        resp = client.request(method, path, headers={"Authorization": "Bearer nope"})
        assert resp.status_code == 401, f"{method} {path}: {resp.status_code}"
