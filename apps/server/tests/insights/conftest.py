"""Fixtures shared by the insights suites.

``challenge_owner_with_history`` lives here rather than in ``_challenge_bed`` so pytest
discovers it by name: a fixture imported into a module reads as an unused import to
every linter, and the fix for that is the mechanism pytest already provides. It is
prefixed rather than named ``owner_with_history`` because the challenges suite has a
fixture of that name with a different anchor (fixed dates there, the wall clock here),
and two fixtures with one name in one run is a trap waiting for the next reader.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import timedelta

import pytest
from tests.challenges import _gen, _seed

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, user_today
from healthee.db import migrate


@pytest.fixture
def challenge_owner_with_history(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on the DB
    """Seven days at 5,000 steps ending yesterday — the band is a known [6000, 6500].

    Anchored to the owner's OWN today, unlike the challenges suite's fixed dates, because
    the coach tools deliberately take no ``today`` parameter: a test hook on a production
    signature is a second code path, so the wall clock is the input the code reads.
    """
    migrate.apply_migrations()
    _seed.reset()
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(_seed.OWNER) as cur:
        _seed.seed_metric(
            cur,
            _seed.OWNER,
            "steps_total",
            {today - timedelta(days=i): _gen.BASELINE_STEPS for i in range(1, 8)},
        )
    yield
    _seed.reset()
