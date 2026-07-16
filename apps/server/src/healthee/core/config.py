"""Application settings — the ONE place environment variables are read.

There are TWO env templates, one per deployment context, and every var must be
present in the one(s) that need it — they are not copies of each other:
  * `infra/.env.example` — the compose/prod template (consumed by
    docker-compose.prod.yml, deploy.sh, backup/). Its Postgres host is the `db`
    service name, and it carries the deploy/backup vars the container never sees.
  * `apps/server/.env.example` — the local-dev template for `apps/server/.env`
    (Postgres on localhost; what the test suite and `scripts/model_eval.py` read).
Adding a setting below means adding it to BOTH unless it is genuinely
context-specific — a var that exists in only one silently defaults in the other,
which is how a blank model id reaches OpenRouter as a 400 in prod.

No other module in the codebase may touch `os.environ` — they call
`get_settings()` instead (standards §2: "config (pydantic-settings ONLY)").

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

    # ── Supabase auth (Phase 6 identity — verify JWTs, never issue) ───────
    # Supabase is the managed auth provider; the API is a resource server that
    # VERIFIES the access JWT (never mints one). The legacy HS256 shared secret
    # signs the token — we verify with the same secret. Blank ⇒ auth fails closed.
    supabase_jwt_secret: str = ""
    # Service-role key for later admin/webhook work (delete-user cascade, §4.5).
    supabase_service_role_key: str = ""
    # Project ref builds the expected issuer https://<ref>.supabase.co/auth/v1;
    # blank ⇒ the `iss` check is skipped (dev / self-signed test tokens).
    supabase_project_ref: str = ""
    # Expected `aud` claim on a Supabase access token (default for its auth server).
    supabase_jwt_aud: str = "authenticated"
    # ── Signup gating (MULTI_USER.md §4, §13 [D1]) ────────────────────────
    # Invite-gated by config now, self-serve flippable later. The SERVER is the
    # trust boundary (§12.7), so this is enforced here — in `supabase_auth.
    # _provision_user` — and not merely as a Supabase dashboard toggle. It gates
    # the creation of a NEW `app_user` row only; an owner who already has a row is
    # always let through (gating accounts, not access).
    #   signups_open=True                  ⇒ anyone Supabase authenticates.
    #   signups_open=False + allowlist     ⇒ only those verified emails.
    #   signups_open=False + no allowlist  ⇒ nobody new (the default).
    signups_open: bool = False
    # Comma-separated invite allowlist, e.g. "a@b.com, c@d.com". A plain str (not
    # list[str]) because pydantic-settings parses complex types as JSON, and an
    # operator setting one env var should not have to write a JSON array. Read it
    # via `signup_allowlist_emails`, never raw.
    signup_allowlist: str = ""

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
    def signup_allowlist_emails(self) -> frozenset[str]:
        """The invite allowlist as lowercased emails — the ONE parse of that var.

        Lowercased (not casefolded) to match `app_user.email`'s CITEXT semantics,
        which compare via `lower()`: an allowlist entry and the mirrored row must
        agree about what "the same email" means. Blank entries are dropped, so a
        trailing comma or an empty var can never allow anyone.
        """
        return frozenset(
            entry.strip().lower() for entry in self.signup_allowlist.split(",") if entry.strip()
        )

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
