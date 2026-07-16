"""DB-suite fixtures.

`claimable` lives here rather than in the test module because that is how a pytest
fixture is shared without importing it by name (which ruff reads, correctly, as a
redefinition at every test that requests it). The seed helpers it calls are in
`_claim_seed.py`.
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from tests.db._claim_seed import (
    MARK,
    OCCUPIED,
    TARGET,
    TARGET_EMAIL,
    TARGET_TZ,
    delete_marked,
    provision,
    restore_sentinel,
    seed_every_tenant_table,
)

from healthee.core.db import transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.db import migrate


@pytest.fixture
def claimable(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    """The live situation: the sentinel owns everything; the real owner just signed in."""
    migrate.apply_migrations()
    with transaction() as cur:
        restore_sentinel(cur)
        seed_every_tenant_table(cur, SENTINEL_USER_ID)
        cur.execute(
            "INSERT INTO device_token (user_id, token_hash, label) VALUES (%s, %s, %s)",
            (SENTINEL_USER_ID, MARK, MARK),
        )
        provision(cur, TARGET, TARGET_EMAIL, TARGET_TZ)
    yield
    with transaction() as cur:
        restore_sentinel(cur)
        delete_marked(cur)
        cur.execute("DELETE FROM app_user WHERE id IN (%s, %s)", (TARGET, OCCUPIED))
