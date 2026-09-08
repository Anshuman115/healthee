"""Dev-only: dump the live seeded responses so new contract KEYS can be hand-applied.

Skipped unless ``HEALTHEE_DUMP_CONTRACTS`` names a directory. It exists because
``packages/contracts/README.md`` forbids regenerating the snapshots wholesale —
``generate.py`` seeds from ``now()``, so a full regeneration re-dates every payload and
turns hundreds of mobile tests red while changing nothing about the contract. Dumping the
live shape and merging only the added and removed keys is the "hand-apply the new keys
only" rule, done by a machine so it cannot miss one.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest
from tests.contracts.endpoints import call_all

pytestmark = pytest.mark.integration


@pytest.mark.skipif(
    not os.environ.get("HEALTHEE_DUMP_CONTRACTS"),
    reason="dev tool; set HEALTHEE_DUMP_CONTRACTS=<dir> to run",
)
def test_dump_live_responses(seeded_client: tuple) -> None:
    """Write every live response to ``$HEALTHEE_DUMP_CONTRACTS/<name>.json``."""
    out = Path(os.environ["HEALTHEE_DUMP_CONTRACTS"])
    out.mkdir(parents=True, exist_ok=True)
    client, headers = seeded_client
    for name, payload in call_all(client, headers).items():
        (out / f"{name}.json").write_text(json.dumps(payload, indent=2, sort_keys=True))
