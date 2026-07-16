"""Application settings — the ONE place environment variables are read.

Every var lives in `infra/.env.example`; docker-compose injects them into the
container environment, and pydantic-settings reads them here. No other module in
the codebase may touch `os.environ` — they call `get_settings()` instead
(standards §2: "config (pydantic-settings ONLY)").

The accessor is import-safe: nothing is constructed at import time, so importing
this module never fails even when required vars are unset. `get_settings()`
constructs (and caches) the singleton on first call, where a misconfiguration
fails loudly instead of silently defaulting.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Typed view of the process environment. Field names map case-insensitively
    to the env vars in `infra/.env.example`."""

    model_config = SettingsConfigDict(
        env_file=".env",  # optional local override; env vars still win
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # ── Postgres / TimescaleDB ────────────────────────────────────────────
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "healthee"
    postgres_user: str = "healthee"
    # Effectively required — a blank DB password is a misconfiguration, not a
    # default. The validator below turns "unset/empty" into a loud failure while
    # keeping the field constructible from the environment.
    postgres_password: str = ""

    # ── API auth (required in production; blank means "reject everything") ──
    # Bearer token expected on every /ingest/* and /api/* request.
    realtime_ingest_token: str = ""

    # ── FastAPI bind (inside the container) ───────────────────────────────
    api_host: str = "0.0.0.0"  # noqa: S104 — LAN-reachable by design (mobile app)
    api_port: int = 8765

    # ── OpenRouter (optional — grounded LLM insights, wired in a later WP) ─
    openrouter_api_key: str = ""
    # LLM model ids — kept in env (DEFAULT_MODEL / COACH_MODEL), NOT hardcoded, so the
    # source never reveals which models we run. Blank here (nothing leaked to git);
    # real values live in the deploy env / a local .env. default_model = the cheap
    # high-volume tier; coach_model = the stronger tier for the interactive coach.
    default_model: str = ""
    coach_model: str = ""

    # ── Telegram notifications (optional — job status + failures) ─────────
    telegram_bot_token: str = ""
    telegram_chat_id: str = ""

    # ── Logging ───────────────────────────────────────────────────────────
    log_level: str = "INFO"

    @field_validator("postgres_password")
    @classmethod
    def _require_password(cls, value: str) -> str:
        if not value:
            raise ValueError("POSTGRES_PASSWORD must be set")
        return value

    @property
    def db_url(self) -> str:
        """libpq connection string for psycopg (used by the pool in core/db)."""
        return (
            f"host={self.postgres_host} port={self.postgres_port} "
            f"dbname={self.postgres_db} user={self.postgres_user} "
            f"password={self.postgres_password}"
        )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return the process-wide Settings singleton, constructing it on first call.

    Cached so every caller shares one instance. `get_settings.cache_clear()` in a
    test fixture forces a re-read after patching the environment.
    """
    return Settings()
