"""Fixtures shared by the challenges suites.

``owner_with_history`` lives here rather than in ``_gen`` so pytest discovers it by name:
a fixture imported into a module reads as an unused import to every linter, and the fix
for that is the mechanism pytest already provides.
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from tests.challenges import _seed
from tests.challenges._gen import steps_history

from healthee.core.db import tenant_transaction
from healthee.db import migrate


@pytest.fixture
def owner_with_history(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(cur, _seed.OWNER, "steps_total", steps_history())
    yield
    _seed.reset()
