"""The signup gate — who may CREATE an account (MULTI_USER.md §4, §13 [D1]).

`signups_open` used to be a dead flag: declared in config, enforced nowhere, with
`_provision_user` asserting that invite-gating "is enforced at Supabase". A Supabase
dashboard toggle is not a control this server owns, and §12.7 is explicit that the
**server** is the trust boundary. This file pins the gate that now exists.

What is being protected is **cost**, not isolation: a stranger's tenant is empty and
stays isolated, but since 6.4c every active owner gets a nightly LLM chain, so
uncontrolled provisioning is uncontrolled spend (PRICING.md §6 — free-tier cost
control is existential).

The two invariants worth naming:

1. **Gating creates accounts, it does not gate access.** An owner who already has an
   `app_user` row always passes, so flipping the flag can never lock out an existing
   user — including the sentinel, whose row 0003 seeds, which is why the legacy shared
   token is unaffected.
2. **Refusal happens before any write.** Every refusal test asserts the row COUNT, not
   just the status code: a 403 that still provisioned the row would defeat the point.

Needs a real DB (provisioning is a database fact); auto-skips without one.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import jwt
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from healthee.core import db as db_module
from healthee.core.config import get_settings
from healthee.core.db import transaction
from healthee.core.request_auth import CurrentUser
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate

pytestmark = pytest.mark.integration

# >= 32 bytes: PyJWT warns (InsecureKeyLengthWarning) on shorter HMAC keys.
_SECRET = "signup-gate-supabase-secret-0123456789abcdef"
_AUD = "authenticated"
_LEGACY_TOKEN = "signup-gate-legacy-token"

_INVITED = "Invited.Owner@Example.com"  # deliberately mixed-case (CITEXT semantics)
_STRANGER = "stranger@example.com"


def _token(sub: UUID, email: str | None = None) -> str:
    payload: dict[str, Any] = {
        "sub": str(sub),
        "aud": _AUD,
        "exp": datetime.now(tz=UTC) + timedelta(hours=1),
    }
    if email is not None:
        payload["email"] = email
    return jwt.encode(payload, _SECRET, algorithm="HS256")


@pytest.fixture
def gate(monkeypatch: pytest.MonkeyPatch, db: None) -> Iterator[pytest.MonkeyPatch]:  # noqa: ARG001
    """Supabase verification configured, signups CLOSED, allowlist empty.

    The strictest posture is the default so each test opens exactly the one door it
    is about — a test that forgets to is refused, not accidentally allowed.
    """
    monkeypatch.setenv("SUPABASE_JWT_SECRET", _SECRET)
    monkeypatch.setenv("SUPABASE_JWT_AUD", _AUD)
    monkeypatch.delenv("SUPABASE_PROJECT_REF", raising=False)
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _LEGACY_TOKEN)
    monkeypatch.setenv("SIGNUPS_OPEN", "false")
    monkeypatch.setenv("SIGNUP_ALLOWLIST", "")
    get_settings.cache_clear()
    migrate.apply_migrations()
    yield monkeypatch
    get_settings.cache_clear()
    db_module.close_pool()


def _client() -> TestClient:
    app = FastAPI()

    @app.get("/whoami")
    def _whoami(user: CurrentUser) -> dict[str, str]:
        return {"id": str(user.id), "timezone": user.timezone}

    return TestClient(app)


def _get(token: str) -> Any:
    return _client().get("/whoami", headers={"Authorization": f"Bearer {token}"})


def _row_count(user_id: UUID) -> int:
    with transaction() as cur:
        cur.execute("SELECT count(*) FROM app_user WHERE id = %s", (str(user_id),))
        row = cur.fetchone()
    assert row is not None
    return int(row[0])


def _forget(user_id: UUID) -> None:
    with transaction() as cur:
        cur.execute("DELETE FROM app_user WHERE id = %s", (str(user_id),))


# --- refusal: closed + not invited -------------------------------------------


def test_a_new_owner_is_refused_403_and_no_row_is_written(gate: pytest.MonkeyPatch) -> None:  # noqa: ARG001
    """403 (not 401 — they authenticated fine) and NOTHING is provisioned."""
    uid = uuid4()
    resp = _get(_token(uid, email=_STRANGER))
    assert resp.status_code == 403
    assert _row_count(uid) == 0, "a refused signup must leave no app_user row"


def test_the_403_body_is_clear_and_leaks_no_secret(gate: pytest.MonkeyPatch) -> None:  # noqa: ARG001
    detail = _get(_token(uuid4(), email=_STRANGER)).json()["detail"]
    assert detail == "Signups are closed"
    assert _SECRET not in detail
    assert _LEGACY_TOKEN not in detail


def test_a_token_with_no_email_claim_is_refused(gate: pytest.MonkeyPatch) -> None:
    """No email ⇒ cannot be on the allowlist ⇒ refused. Never an optimistic guess."""
    gate.setenv("SIGNUP_ALLOWLIST", _INVITED)  # non-empty: the list exists, they aren't on it
    get_settings.cache_clear()
    uid = uuid4()
    assert _get(_token(uid, email=None)).status_code == 403
    assert _row_count(uid) == 0


# --- the two ways in ----------------------------------------------------------


def test_an_allowlisted_owner_is_provisioned(gate: pytest.MonkeyPatch) -> None:
    gate.setenv("SIGNUP_ALLOWLIST", f"someone@else.com,{_INVITED}")
    get_settings.cache_clear()
    uid = uuid4()
    try:
        resp = _get(_token(uid, email=_INVITED))
        assert resp.status_code == 200
        assert resp.json()["id"] == str(uid)
        assert _row_count(uid) == 1
    finally:
        _forget(uid)


def test_the_allowlist_is_case_insensitive_both_ways(gate: pytest.MonkeyPatch) -> None:
    """`app_user.email` is CITEXT; the allowlist matches that semantic, not bytes."""
    gate.setenv("SIGNUP_ALLOWLIST", "  UPPER@Example.COM , spaced@example.com  ")
    get_settings.cache_clear()
    uid = uuid4()
    try:
        assert _get(_token(uid, email="upper@example.com")).status_code == 200
    finally:
        _forget(uid)
    other = uuid4()
    try:
        assert _get(_token(other, email="SPACED@EXAMPLE.COM")).status_code == 200
    finally:
        _forget(other)


def test_open_signups_provision_anyone(gate: pytest.MonkeyPatch) -> None:
    gate.setenv("SIGNUPS_OPEN", "true")
    get_settings.cache_clear()
    uid = uuid4()
    try:
        assert _get(_token(uid, email=_STRANGER)).status_code == 200
        assert _row_count(uid) == 1
    finally:
        _forget(uid)


def test_open_signups_provision_a_token_with_no_email(gate: pytest.MonkeyPatch) -> None:
    """ "Open" means open — the email only matters when the allowlist is the gate."""
    gate.setenv("SIGNUPS_OPEN", "true")
    get_settings.cache_clear()
    uid = uuid4()
    try:
        assert _get(_token(uid, email=None)).status_code == 200
    finally:
        _forget(uid)


# --- gating never locks out an EXISTING owner ---------------------------------


def test_an_existing_owner_passes_while_signups_are_closed(gate: pytest.MonkeyPatch) -> None:
    """The bootstrap-deadlock guarantee, and the "gate accounts, not access" rule.

    An owner provisioned while the door was open (or by the allowlist, or by the
    claim) keeps working after it shuts. Otherwise closing signups would lock out
    every user the moment an invite were revoked.
    """
    uid = uuid4()
    gate.setenv("SIGNUPS_OPEN", "true")
    get_settings.cache_clear()
    try:
        assert _get(_token(uid, email=_STRANGER)).status_code == 200
        gate.setenv("SIGNUPS_OPEN", "false")
        gate.setenv("SIGNUP_ALLOWLIST", "")  # not invited, not open — but already a user
        get_settings.cache_clear()
        resp = _get(_token(uid, email=_STRANGER))
        assert resp.status_code == 200
        assert resp.json()["id"] == str(uid)
    finally:
        _forget(uid)


def test_the_legacy_shared_token_still_resolves_to_the_sentinel(
    gate: pytest.MonkeyPatch,  # noqa: ARG001
) -> None:
    """The sentinel's row already exists (0003), so the gate cannot touch it.

    The un-rebuilt app authenticates with this token; if closing signups broke it,
    the gate would have broken prod (MULTI_USER.md §4.4a).
    """
    resp = _get(_LEGACY_TOKEN)
    assert resp.status_code == 200
    assert resp.json()["id"] == str(SENTINEL_USER_ID)
    assert resp.json()["timezone"] == SENTINEL_TZ


# --- the allowlist parse ------------------------------------------------------


def test_an_empty_allowlist_admits_nobody(gate: pytest.MonkeyPatch) -> None:
    """A blank/comma-only var must never parse into an entry that matches "" or all."""
    for value in ("", "   ", ",", " , , "):
        gate.setenv("SIGNUP_ALLOWLIST", value)
        get_settings.cache_clear()
        assert get_settings().signup_allowlist_emails == frozenset(), value
        uid = uuid4()
        assert _get(_token(uid, email=_STRANGER)).status_code == 403, value
        assert _row_count(uid) == 0
