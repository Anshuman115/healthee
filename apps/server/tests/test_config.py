"""Unit tests for core.config — parsing, defaults, and the singleton accessor."""

from __future__ import annotations

import pytest

from healthee.core.config import Settings, get_settings


def test_defaults_apply_when_only_required_var_set(
    env: None,  # noqa: ARG001 — sets the required password
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Clear any ambient POSTGRES_* (a developer shell or CI with POSTGRES_PORT set
    # would otherwise fail this defaults test) so it exercises the code defaults.
    for var in ("POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_DB", "POSTGRES_USER"):
        monkeypatch.delenv(var, raising=False)
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.postgres_host == "localhost"
    assert settings.postgres_port == 5432
    assert settings.postgres_db == "healthee"
    assert settings.api_port == 8765
    assert settings.log_level == "INFO"
    # Optional integrations default to empty (they no-op when blank).
    assert settings.openrouter_api_key == ""
    assert settings.telegram_bot_token == ""


def test_env_vars_override_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("POSTGRES_PASSWORD", "pw")
    monkeypatch.setenv("POSTGRES_HOST", "db.internal")
    monkeypatch.setenv("POSTGRES_PORT", "5544")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.postgres_host == "db.internal"
    assert settings.postgres_port == 5544
    assert settings.log_level == "DEBUG"
    get_settings.cache_clear()


def test_admin_db_url_is_libpq_conninfo(monkeypatch: pytest.MonkeyPatch) -> None:
    # Clear ambient host/port/user so the conninfo reflects the code defaults,
    # not whatever a dev shell exported.
    for var in ("POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_USER"):
        monkeypatch.delenv(var, raising=False)
    monkeypatch.setenv("POSTGRES_PASSWORD", "s3cret")
    monkeypatch.setenv("POSTGRES_DB", "healthee")
    get_settings.cache_clear()
    url = get_settings().admin_db_url
    assert "dbname=healthee" in url
    assert "password=s3cret" in url
    assert "host=localhost" in url
    get_settings.cache_clear()


# ── the app-role credential split (6.5b-1, MULTI_USER.md §3.3) ────────────────


def test_app_db_url_falls_back_to_the_admin_creds(env: None) -> None:  # noqa: ARG001
    """Unset app creds ⇒ exactly the pre-split behaviour, so this is safe to deploy
    before the role is provisioned. `core/db` warns that RLS cannot apply."""
    settings = get_settings()
    assert settings.app_role_configured is False
    assert settings.app_db_url == settings.admin_db_url


def test_app_db_url_uses_the_app_creds_when_set(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("POSTGRES_PASSWORD", "admin-pw")
    monkeypatch.setenv("POSTGRES_USER", "healthee")
    monkeypatch.setenv("POSTGRES_APP_USER", "healthee_app")
    monkeypatch.setenv("POSTGRES_APP_PASSWORD", "app-pw")
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.app_role_configured is True
    assert "user=healthee_app " in settings.app_db_url
    assert "password=app-pw" in settings.app_db_url
    # The admin identity is unchanged — the two never bleed into each other.
    assert "user=healthee " in settings.admin_db_url
    assert "password=admin-pw" in settings.admin_db_url
    get_settings.cache_clear()


def test_half_set_app_creds_are_a_loud_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    """Refuse the ambiguity: silently connecting as the ADMIN while the operator
    believes the least-privilege role is in force is the exact security theatre the
    split exists to end."""
    monkeypatch.setenv("POSTGRES_PASSWORD", "admin-pw")
    monkeypatch.setenv("POSTGRES_APP_USER", "healthee_app")
    monkeypatch.delenv("POSTGRES_APP_PASSWORD", raising=False)
    with pytest.raises(ValueError, match="must be set together"):
        Settings()
    monkeypatch.delenv("POSTGRES_APP_USER")
    monkeypatch.setenv("POSTGRES_APP_PASSWORD", "app-pw")
    with pytest.raises(ValueError, match="must be set together"):
        Settings()


def test_missing_password_is_a_loud_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("POSTGRES_PASSWORD", raising=False)
    with pytest.raises(ValueError):  # pydantic ValidationError is a ValueError
        Settings()


def test_get_settings_is_cached(env: None) -> None:  # noqa: ARG001
    assert get_settings() is get_settings()
