"""Regenerate the committed contract snapshots from a freshly seeded DB.

Run against a reachable TimescaleDB:

    POSTGRES_* … REALTIME_INGEST_TOKEN=… uv run python -m tests.contracts.generate

Writes one ``<endpoint>.json`` per read endpoint into
``packages/contracts/snapshots/``. See ``packages/contracts/README.md``.
"""

from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient
from tests.contracts.endpoints import call_all
from tests.contracts.seed import seed_all

from healthee.api.app import create_app

# apps/server/tests/contracts/generate.py → repo root is four parents up.
SNAPSHOT_DIR = Path(__file__).resolve().parents[4] / "packages" / "contracts" / "snapshots"
_TOKEN = "contract-token"


def generate() -> None:
    """Seed, call every endpoint, and write the snapshot files."""
    seed_all()
    client = TestClient(create_app())
    responses = call_all(client, {"Authorization": f"Bearer {_TOKEN}"})
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    for name, payload in responses.items():
        path = SNAPSHOT_DIR / f"{name}.json"
        path.write_text(json.dumps(payload, indent=2, sort_keys=True, default=str) + "\n")
        print(f"wrote {path.relative_to(SNAPSHOT_DIR.parents[2])}")


if __name__ == "__main__":
    generate()
