"""Shared bed for the WP-C4b program-generation suite: one owner, one known band, one stub.

``_gen``'s twin, and it stands on the same owner: seven days at 5,000 steps before
``TODAY``, so the daily band is the known [6000, 6500] and the evidence target is
``steps_total``'s 8,000/day. That is what makes the point of this WP arithmetic rather
than atmosphere — :data:`ASCENDING` is a ladder whose rung 1 is IN the band and whose
rungs 2-4 are deliberately ABOVE it, which a naive per-rung Gate A would reject and this
pipeline must accept.

Not a pytest module (underscore-prefixed); imported by ``test_program_generation``.
"""

from __future__ import annotations

import json
from typing import Any

from tests.challenges import _seed
from tests.challenges._gen import BAND_HIGH, BAND_LOW, IN_BAND, TODAY
from tests.insights._ids import ESTABLISHED_ID

from healthee.challenges import program_generate
from healthee.core.tenancy import SENTINEL_TZ

IST = SENTINEL_TZ
DAY = TODAY

# The band `_gen` documents, re-exported so a test reads the ladder against it without
# importing two beds.
BAND = (BAND_LOW, BAND_HIGH)

# `targets.EVIDENCE_TARGET["steps_total"]` in daily units — the ceiling a rung may reach
# and not pass. A ladder ending here is the honest maximum.
EVIDENCE_TARGET = 8000.0

# Rung 1 sits inside [6000, 6500]; every rung after it is ABOVE the band on purpose. THIS
# is the WP: a per-rung Gate A rejects rungs 2-4 and therefore rejects every real ladder.
ASCENDING = (IN_BAND, 7000.0, 7500.0, EVIDENCE_TARGET)

RUNG_DAYS = 14


def rung(target: float, **overrides: Any) -> dict:
    """One rung proposal — a challenge's copy fields, minus the ladder's shared shape."""
    proposal = {
        "title": "Add a walk",
        "why": f"A steady step increase may support cardiovascular fitness [{ESTABLISHED_ID}].",
        "expected_outcome": f"More movement may compound across the weeks [{ESTABLISHED_ID}].",
        "how_to": "Two 15-minute walks — one after lunch, one after dinner.",
        "difficulty": "standard",
        "target_value": target,
        "window_days": RUNG_DAYS,
        "research_note_ids": [ESTABLISHED_ID],
    }
    proposal.update(overrides)
    return proposal


def program(*targets: float, **overrides: Any) -> dict:
    """A whole ladder proposal; ``targets`` become its rungs in order."""
    design = {
        "title": "Walk your way up",
        "why": f"Climbing gradually is what the evidence supports [{ESTABLISHED_ID}].",
        "category": "activity",
        "metric": "steps_total",
        "comparator": ">=",
        "cadence": "daily",
        "rungs": [rung(target) for target in (targets or ASCENDING)],
    }
    design.update(overrides)
    return design


def response(*targets: float, **overrides: Any) -> str:
    return json.dumps({"program": program(*targets, **overrides)})


def run_generation(stub: Any, owner: Any = None, **kwargs: Any) -> dict:
    return program_generate.generate_program(
        owner or _seed.OWNER, IST, client=stub, today=DAY, **kwargs
    )
