"""Shared bed for the WP-C3 generation tests: one owner, one known band, one stub.

The LLM is the hard part, so it is scripted: :class:`StubLLM` returns whatever the test
says the model proposed, which is how a proposal nobody would ever get a real model to
emit on demand (a fabricated note id, a 12,000-step target on a 3,000-step baseline) can
be pinned as *impossible to persist* rather than merely unlikely.

Every owner here holds a 5,000-step-a-day history over the seven days before ``TODAY``,
so the daily band is a known [6000, 6500] and every Gate A assertion is arithmetic
against a number the test can state, not against whatever the DB happened to contain.
The baseline is deliberately one where the PERCENTAGE governs the ambitious end
(``targets.MEANINGFUL_STEP`` for steps is 1,000/day, and 30 % of 5,000 is 1,500), so the
bed exercises a band with width rather than the degenerate single point a low baseline
collapses to — the low-baseline cases are known-value tested in ``test_calibration``.

Not a pytest module (underscore-prefixed); imported by the two suites that use it —
``test_generation_gates`` (Gate A + Gate B) and ``test_generation_invariants``
(structure, tenancy, the retry, and the WP-C5 seam).
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime, timedelta

from tests.challenges import _seed
from tests.insights._ids import ESTABLISHED_ID
from tests.insights._stub import StubLLM

from healthee.challenges import generate, store
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ

IST = SENTINEL_TZ
TODAY = date(2026, 7, 15)
BASELINE_STEPS = 5000.0
# `bounds.band_for`: 5000 + max(500, 1000 floor, 250 step) = 6000 … 5000 + max(1500,
# 1000) = 6500, with the 8,000-step evidence target still ahead so nothing is capped.
BAND_LOW, BAND_HIGH = 6000.0, 6500.0
IN_BAND = 6250.0


def steps_history() -> dict[date, float]:
    """Seven measured days strictly before ``TODAY`` — what the baseline is built from."""
    return {TODAY - timedelta(days=i): BASELINE_STEPS for i in range(1, 8)}


def proposal(**overrides) -> dict:
    proposal = {
        "title": "Walk a little more",
        "why": f"A modest step increase may support cardiovascular fitness [{ESTABLISHED_ID}].",
        "expected_outcome": f"Steadier daily movement may compound over the window "
        f"[{ESTABLISHED_ID}].",
        "how_to": "Two 15-minute walks — one after lunch, one after dinner.",
        "category": "activity",
        "difficulty": "standard",
        "metric": "steps_total",
        "comparator": ">=",
        "target_value": IN_BAND,
        "cadence": "daily",
        "window_days": 14,
        "research_note_ids": [ESTABLISHED_ID],
    }
    proposal.update(overrides)
    return proposal


def response(*proposals: dict) -> str:
    return json.dumps({"challenges": list(proposals or (proposal(),))})


def run_generation(stub: StubLLM, owner=None, **kwargs) -> dict:
    return generate.generate_challenges(
        owner or _seed.OWNER, IST, client=stub, today=TODAY, **kwargs
    )


def suggested(owner=None) -> list[dict]:
    with tenant_transaction(owner or _seed.OWNER) as cur:
        return store.list_by_status(cur, owner or _seed.OWNER, ("suggested",))


def seed_caffeine_habit() -> None:
    """Seven days at 200 mg — a `good="down"` baseline, so the cap band is [140, 175]."""
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_manual(
            cur,
            _seed.OWNER,
            "caffeine",
            [
                (datetime(2026, 7, 8, 6, 0, tzinfo=UTC) + timedelta(days=i), 200.0, "mg")
                for i in range(7)
            ],
        )


class AdoptsMidFlight(StubLLM):
    """A stub that takes a slot WHILE the model is "thinking".

    The pipeline reads the world, calls the model, then writes — three steps that cannot
    share a transaction, because holding a pooled connection across a network round-trip
    is how a pool deadlocks. This is the window that opens, simulated at the only moment
    it can be: inside the completion itself.
    """

    def __init__(self, responses: list[str], metric: str = "steps_total") -> None:
        super().__init__(responses)
        self._metric = metric

    def complete(self, messages, **kwargs):
        with tenant_transaction(_seed.OWNER) as cur:
            _seed.seed_challenge(
                cur,
                _seed.OWNER,
                status="active",
                metric=self._metric,
                title=f"Adopted mid-flight ({self._metric})",
                adopted_at=datetime(2026, 7, 14, 6, 0, tzinfo=UTC),
            )
        return super().complete(messages, **kwargs)
