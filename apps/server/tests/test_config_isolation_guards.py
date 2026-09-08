"""The two config validators that refuse a deployment which cannot isolate its tenants.

`AUTH_AUDIT.md` B1 and C3. Both were previously a paragraph — B1 announced by a single
log line at pool open, C3 by a docstring saying the transitional token "MUST NOT survive
into public signups" with nothing enforcing it. `core/config.py` already refused three
other ambiguities with a `model_validator`, so both are now the same shape.

**These tests must clear `ALLOW_ADMIN_DB_FALLBACK` themselves.** The session fixture
`tests/conftest.py::_allow_the_bootstrap_to_build_settings` sets it for the whole run —
the suite's own bootstrap builds `Settings` before it has provisioned a role — so a test
of the refusal has to take it back out. That is deliberate: the opt-out being ON for the
suite is exactly why the refusal needs a test that turns it OFF, or nothing would ever
exercise it.
"""

from __future__ import annotations

import pytest

from healthee.core.config import Settings


@pytest.fixture
def strict(monkeypatch: pytest.MonkeyPatch, env: None) -> pytest.MonkeyPatch:  # noqa: ARG001
    """A hermetic unit environment with the transitional opt-out REMOVED."""
    monkeypatch.delenv("ALLOW_ADMIN_DB_FALLBACK", raising=False)
    return monkeypatch


# ── B1: the pool may not silently become the admin ───────────────────────────


def test_blank_app_creds_refuse_to_boot(strict: pytest.MonkeyPatch) -> None:  # noqa: ARG001
    """The whole finding: leaving a variable blank used to buy an RLS-inert deployment.

    Blank `POSTGRES_APP_*` means the pool connects as the admin, which BYPASSES
    Row-Level Security — so in a multi-tenant product the backstop under every explicit
    `AND user_id = %s` is decoration. Both shipped `.env` templates defaulted to blank,
    so an operator who filled in what was obviously required got exactly this.
    """
    with pytest.raises(ValueError, match="BYPASSES Row-Level Security"):
        Settings()


def test_the_refusal_names_the_way_out(strict: pytest.MonkeyPatch) -> None:  # noqa: ARG001
    """A refusal that does not say what to do next is a wall, not a guard."""
    with pytest.raises(ValueError) as caught:
        Settings()
    message = str(caught.value)
    assert "provision_app_role" in message
    assert "ALLOW_ADMIN_DB_FALLBACK=true" in message


def test_the_explicit_opt_out_keeps_the_bootstrap_deploy_bootable(
    strict: pytest.MonkeyPatch,
) -> None:
    """`infra/DEPLOY.md` B2 step 1 runs on the admin creds BY NECESSITY.

    The role cannot be provisioned before the deploy that provisions it, so refusing
    outright would make the documented procedure impossible. The point of the opt-out is
    that the transitional state has to be ASKED FOR, in a file the next person reads —
    rather than reached by the absence of a value, which looks identical to nobody
    having considered the question.
    """
    strict.setenv("ALLOW_ADMIN_DB_FALLBACK", "true")
    settings = Settings()
    assert settings.app_role_configured is False
    assert settings.app_db_url == settings.admin_db_url  # the fallback, as documented


def test_a_configured_app_role_needs_no_opt_out(strict: pytest.MonkeyPatch) -> None:
    """The normal, correct deployment: both vars set, no flag anywhere."""
    strict.setenv("POSTGRES_APP_USER", "healthee_app")
    strict.setenv("POSTGRES_APP_PASSWORD", "app-secret")
    settings = Settings()
    assert settings.app_role_configured is True
    assert settings.allow_admin_db_fallback is False
    assert settings.app_db_url != settings.admin_db_url


def test_the_opt_out_defaults_to_off(strict: pytest.MonkeyPatch) -> None:
    """A security opt-out that defaulted ON would be the finding, restated."""
    strict.setenv("POSTGRES_APP_USER", "healthee_app")
    strict.setenv("POSTGRES_APP_PASSWORD", "app-secret")
    assert Settings().allow_admin_db_fallback is False


# ── C3: one shared, never-expiring tenant key beside open signups ────────────


def _configured(monkeypatch: pytest.MonkeyPatch) -> None:
    """A deployment that is otherwise valid, so only the C3 pair is under test."""
    monkeypatch.setenv("POSTGRES_APP_USER", "healthee_app")
    monkeypatch.setenv("POSTGRES_APP_PASSWORD", "app-secret")


def test_open_signups_beside_the_legacy_token_refuse_to_boot(
    strict: pytest.MonkeyPatch,
) -> None:
    """The combination `request_auth`'s docstring says must never happen.

    The legacy shared token resolves to ONE REAL TENANT, never expires, and ships inside
    the APK. `MULTI_USER.md` 4 says `signups_open=true` is "gated on that removal" —
    and nothing gated it: two independent fields, no validator between them.
    """
    _configured(strict)
    strict.setenv("REALTIME_INGEST_TOKEN", "a-shared-secret")
    strict.setenv("SIGNUPS_OPEN", "true")
    with pytest.raises(ValueError, match="SIGNUPS_OPEN is true"):
        Settings()


def test_open_signups_with_no_legacy_token_are_fine(strict: pytest.MonkeyPatch) -> None:
    """The post-transition deployment — the state the removal condition describes."""
    _configured(strict)
    strict.setenv("REALTIME_INGEST_TOKEN", "")
    strict.setenv("SIGNUPS_OPEN", "true")
    assert Settings().signups_open is True


def test_the_legacy_token_with_signups_shut_is_fine(strict: pytest.MonkeyPatch) -> None:
    """Today's deployment. The finding is the PAIR, not either half."""
    _configured(strict)
    strict.setenv("REALTIME_INGEST_TOKEN", "a-shared-secret")
    strict.setenv("SIGNUPS_OPEN", "false")
    assert Settings().realtime_ingest_token == "a-shared-secret"


def test_the_refusal_says_which_two_settings_collide(strict: pytest.MonkeyPatch) -> None:
    _configured(strict)
    strict.setenv("REALTIME_INGEST_TOKEN", "a-shared-secret")
    strict.setenv("SIGNUPS_OPEN", "true")
    with pytest.raises(ValueError) as caught:
        Settings()
    assert "REALTIME_INGEST_TOKEN" in str(caught.value)
