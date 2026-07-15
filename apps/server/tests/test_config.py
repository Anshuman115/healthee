"""Unit tests for core.config — parsing, defaults, and the singleton accessor."""

from __future__ import annotations

import pytest

from healthee.core.config import Settings, get_settings


def test_defaults_apply_when_only_required_var_set(env: None) -> None:  # noqa: ARG001
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


def test_db_url_is_libpq_conninfo(monkeypatch: pytest.MonkeyPatch) -> None:
    # Clear ambient host/port/user so the conninfo reflects the code defaults,
    # not whatever a dev shell exported.
    for var in ("POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_USER"):
        monkeypatch.delenv(var, raising=False)
    monkeypatch.setenv("POSTGRES_PASSWORD", "s3cret")
    monkeypatch.setenv("POSTGRES_DB", "healthee")
    get_settings.cache_clear()
    url = get_settings().db_url
    assert "dbname=healthee" in url
    assert "password=s3cret" in url
    assert "host=localhost" in url
    get_settings.cache_clear()


def test_missing_password_is_a_loud_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("POSTGRES_PASSWORD", raising=False)
    with pytest.raises(ValueError):  # pydantic ValidationError is a ValueError
        Settings()


def test_get_settings_is_cached(env: None) -> None:  # noqa: ARG001
    assert get_settings() is get_settings()
