"""HTTP behaviour of the two generation endpoints (WP-C3b, WP-C4b).

The pipeline's own gates are ``tests/challenges/test_generation_*``; this pins what the
ENDPOINT does, which is four things the pipeline cannot be asked about:

* generation reaches the database end to end through HTTP, with the model stubbed;
* the daily budget refuses the (N+1)-th request as a **429 that says when it lifts** —
  not a generic error, and not a 500;
* a refusal that never asked the model does not COST a unit — an owner must not lose
  their day's refreshes to a state they can fix in a tap;
* **``GET /api/challenges`` is still pure.** It writes no row and asks no model, even
  with an empty feed. WP-C2 established that deliberately and WP-C3b is exactly the
  change that would have been tempted to break it;
* the two endpoints share ONE budget — a challenge and a ladder are the same pipeline
  shape and the same money, so two budgets would be two ways to spend it.

The LLM is stubbed at ``insights.grounded.get_client``, so no network call happens — the
same policy every other insights test follows.

Auto-skips without a reachable TimescaleDB (the contract bed's policy).
"""

from __future__ import annotations

import json
import time
from collections.abc import Iterator
from datetime import timedelta
from typing import Any

import pytest
from tests.challenges import _seed
from tests.challenges._gen import BAND_LOW, IN_BAND, proposal, response
from tests.challenges._program_gen import response as program_response
from tests.insights._stub import StubLLM

from healthee.api.routers import generation as generation_router
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, user_today

pytestmark = pytest.mark.integration

# The owner's own history, re-seeded relative to the REAL local today: the endpoint
# anchors on `user_today(tz)` and a fixture pinned to a fixed date would calibrate
# against seven days that are not in the baseline window at all. 5,000 steps/day gives
# the band [6000, 6500] `_gen` documents, so `IN_BAND` is in band here too.
_BASELINE_STEPS = 5000.0
_HISTORY_DAYS = 7


@pytest.fixture
def generating_client(
    seeded_client: tuple, monkeypatch: pytest.MonkeyPatch
) -> Iterator[tuple[Any, dict, StubLLM]]:
    """The contract client, a world of exactly one owner's step history, and a stub model.

    The bed is RESET rather than added to: the contract seed carries a live challenge, a
    live ladder and a suggestion, and generation's answer depends on all three. A test
    about the endpoint should not also be a test about that fixture's cap arithmetic.
    """
    client, headers = seeded_client
    _seed.reset()
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur,
            _seed.OWNER,
            "steps_total",
            {today - timedelta(days=i): _BASELINE_STEPS for i in range(1, _HISTORY_DAYS + 1)},
        )
        cur.execute("DELETE FROM kv WHERE user_id = %s", (_seed.OWNER,))
    stub = StubLLM([response()])
    monkeypatch.setattr("healthee.insights.grounded.get_client", lambda: stub)
    yield client, headers, stub
    _seed.reset()


def _generate(client: Any, headers: dict) -> Any:
    return client.post("/api/challenges/generate", headers=headers)


def _generate_program(client: Any, headers: dict) -> Any:
    return client.post("/api/programs/generate", headers=headers)


def test_generation_reaches_the_feed_end_to_end(generating_client: tuple) -> None:
    """One POST, and the owner has a suggestion they can adopt — the whole point of C3b.

    The stored target is asserted because that is the honesty-critical half: Gate A
    rejects rather than clamps, so a challenge that lands carries the number the model
    wrote its copy around.
    """
    client, headers, _ = generating_client
    resp = _generate(client, headers)

    assert resp.status_code == 200, resp.text[:300]
    body = resp.json()
    assert (body["ok"], body["generated"], body["rejected"]) == (True, 1, [])
    assert body["challenges"][0]["target_value"] == IN_BAND
    feed = client.get("/api/challenges", headers=headers).json()
    assert [c["id"] for c in feed["suggested"]] == [body["challenges"][0]["id"]]


def test_the_budget_refuses_honestly_and_says_when_it_lifts(generating_client: tuple) -> None:
    """The (N+1)-th request is a 429 with a Retry-After and a resetting instant.

    A generic 500, or a 200 with an empty feed, would both be lies about what happened —
    and a refusal an owner cannot act on is the silent degraded state standards §Errors
    forbids.
    """
    client, headers, stub = generating_client
    limit = generation_router.GENERATIONS_PER_DAY
    allowed = [_generate(client, headers).status_code for _ in range(limit)]
    refused = _generate(client, headers)

    assert allowed == [200] * limit
    assert refused.status_code == 429
    detail = refused.json()["detail"]
    assert detail["reason"] == "generation_budget_spent"
    assert (detail["limit"], detail["used"]) == (limit, limit + 1)
    assert int(refused.headers["Retry-After"]) > 0
    assert detail["resets_at"].startswith("20")  # an instant, not a vague "later"
    # And the refusal COST nothing: the model was asked exactly once per allowed request.
    assert stub.calls == limit


def test_a_refusal_that_never_asked_the_model_does_not_cost_a_unit(
    generating_client: tuple,
) -> None:
    """An owner at the challenge cap gets a 409 back, and keeps their whole budget.

    ``too_many_active`` is decided before the model is reached (``generate._prepare``), so
    charging for it would let somebody lose a day's refreshes to a state they can fix by
    finishing a challenge — while the spend this budget exists to bound went unspent.
    """
    client, headers, stub = generating_client
    with tenant_transaction(_seed.OWNER) as cur:
        for i in range(3):
            _seed.seed_challenge(
                cur, _seed.OWNER, status="active", title=f"Live {i}", metric="steps_total"
            )

    for _ in range(generation_router.GENERATIONS_PER_DAY + 1):
        refused = _generate(client, headers)
        assert refused.status_code == 409, refused.text[:200]
        assert refused.json()["detail"]["reason"] == "too_many_active"
    assert stub.calls == 0


def test_the_read_path_stays_pure_even_with_an_empty_feed(generating_client: tuple) -> None:
    """A GET generates nothing, writes nothing, and asks nobody. WP-C2's rule, kept.

    The tempting shape for C3b was auto-generate-on-empty-feed. It is refused: a GET that
    writes is not idempotent, races itself, and would only ever help the owner who happens
    to be looking. The client calls generate; the read reports.
    """
    client, headers, stub = generating_client
    feed = client.get("/api/challenges", headers=headers)

    assert feed.status_code == 200
    assert feed.json()["suggested"] == []
    assert stub.calls == 0
    with tenant_transaction(_seed.OWNER) as cur:
        cur.execute("SELECT count(*) FROM challenge WHERE user_id = %s", (_seed.OWNER,))
        found = cur.fetchone()
    assert found is not None and found[0] == 0


def test_a_rejected_batch_is_reported_rather_than_silently_empty(
    generating_client: tuple, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Nothing shipped, and the endpoint SAYS why — §2.5's fix, on the wire.

    Both attempts propose a target far outside the owner's band, so Gate A takes the whole
    batch twice and the honest answer is an empty feed with its reasons attached.
    """
    client, headers, _ = generating_client
    out_of_band = json.dumps({"challenges": [proposal(target_value=BAND_LOW * 3)]})
    monkeypatch.setattr(
        "healthee.insights.grounded.get_client", lambda: StubLLM([out_of_band, out_of_band])
    )
    resp = _generate(client, headers)

    assert resp.status_code == 200
    body = resp.json()
    assert (body["generated"], body["challenges"]) == (0, [])
    assert any("progressive-overload band" in reason for reason in body["rejected"])


def test_generation_requires_authentication(generating_client: tuple) -> None:
    """Premium gating (6.6) is NOT built, so authentication is the line that does exist."""
    client, _, _ = generating_client
    resp = client.post("/api/challenges/generate", headers={"Authorization": "Bearer nope"})
    assert resp.status_code == 401


def test_the_server_side_half_of_a_generation_is_cheap(generating_client: tuple) -> None:
    """With the model stubbed, everything else the endpoint does fits the READ budget.

    The request's latency is the model's and nothing else's, and that is a claim worth
    measuring rather than asserting: what this server contributes is two short
    owner-scoped transactions (build the context, persist), and if either grew an N+1 or a
    per-metric round-trip the number below would move. Generous headroom over the
    p95 < 100 ms read budget because a stubbed run still builds the whole v2 context and
    reads the corpus manifest, and the bound has to be a regression detector rather than a
    flake on a busy laptop.
    """
    client, headers, _ = generating_client
    timings = []
    for _ in range(2):
        started = time.perf_counter()
        resp = _generate(client, headers)
        timings.append((time.perf_counter() - started) * 1000)
        assert resp.status_code == 200

    print(f"\nnon-LLM half: cold {timings[0]:.0f} ms, warm {timings[1]:.0f} ms")  # noqa: T201
    assert timings[-1] < 1500, f"generation's non-LLM half took {timings[-1]:.0f} ms"


# ── WP-C4b: the program endpoint, on the same budget ──────────────────────────


def test_a_ladder_reaches_the_program_feed_end_to_end(
    generating_client: tuple, monkeypatch: pytest.MonkeyPatch
) -> None:
    """One POST, and the owner has a ladder they can adopt — WP-C4b's whole point.

    Every rung comes back ``locked``: designing is not starting, and ``adopt`` is what
    recalibrates rung 1 against their baseline at the moment they commit.
    """
    client, headers, _ = generating_client
    monkeypatch.setattr(
        "healthee.insights.grounded.get_client", lambda: StubLLM([program_response()])
    )
    resp = _generate_program(client, headers)

    assert resp.status_code == 200, resp.text[:300]
    body = resp.json()
    assert (body["ok"], body["generated"], body["rejected"]) == (True, 1, [])
    assert [r["status"] for r in body["program"]["rungs"]] == ["locked"] * 4
    feed = client.get("/api/programs", headers=headers).json()
    assert [p["id"] for p in feed["suggested"]] == [body["program"]["id"]]
    assert feed["active"] is None


def test_a_refused_ladder_design_is_a_200_that_says_why(
    generating_client: tuple, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A cap ladder is not expressible, and the endpoint says so rather than erroring.

    The pipeline worked; the model's ladder did not. That is ``generated: 0`` with the
    reason attached, not a 5xx and not an empty 200 — the two are different answers.
    """
    client, headers, _ = generating_client
    cap = program_response(175.0, 160.0, 150.0, metric="caffeine_mg", comparator="<=")
    monkeypatch.setattr("healthee.insights.grounded.get_client", lambda: StubLLM([cap, cap]))
    resp = _generate_program(client, headers)

    assert resp.status_code == 200
    body = resp.json()
    assert (body["generated"], body["program"]) == (0, None)
    assert body["rejected"][0].startswith("not_ladderable: ")


def test_both_endpoints_draw_on_one_budget(
    generating_client: tuple, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Two challenge refreshes and one ladder spend the day — the fourth request is 429.

    Whichever door it came through: the money is the same money.
    """
    client, headers, _ = generating_client
    monkeypatch.setattr(
        "healthee.insights.grounded.get_client",
        lambda: StubLLM([response(), program_response()]),
    )
    assert _generate(client, headers).status_code == 200
    assert _generate(client, headers).status_code == 200
    assert _generate_program(client, headers).status_code == 200

    assert _generate_program(client, headers).status_code == 429
    assert _generate(client, headers).status_code == 429


def test_the_program_read_path_stays_pure(generating_client: tuple) -> None:
    """GET /api/programs designs nothing, exactly as GET /api/challenges generates nothing."""
    client, headers, stub = generating_client
    feed = client.get("/api/programs", headers=headers)

    assert feed.status_code == 200
    assert (feed.json()["active"], feed.json()["suggested"]) == (None, [])
    assert stub.calls == 0
    with tenant_transaction(_seed.OWNER) as cur:
        cur.execute("SELECT count(*) FROM program WHERE user_id = %s", (_seed.OWNER,))
        found = cur.fetchone()
    assert found is not None and found[0] == 0


def test_program_generation_requires_authentication(generating_client: tuple) -> None:
    """Premium gating (6.6) is NOT built, so authentication is the line that does exist."""
    client, _, _ = generating_client
    resp = client.post("/api/programs/generate", headers={"Authorization": "Bearer nope"})
    assert resp.status_code == 401
