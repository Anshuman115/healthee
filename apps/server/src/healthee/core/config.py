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
from typing import Self

from pydantic import field_validator, model_validator
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
    # The OWNER/ADMIN identity: owns the tables, runs migrations (DDL),
    # `db.claim_sentinel`, `db.provision_app_role`, and the test reset. It is NOT
    # the identity that serves requests — see the app role below. Prod already has
    # these set and their meaning is unchanged.
    postgres_user: str = "healthee"
    # Effectively required — a blank DB password is a misconfiguration, not a
    # default. The validator below turns "unset/empty" into a loud failure while
    # keeping the field constructible from the environment.
    postgres_password: str = ""

    # ── Postgres application role (least privilege — MULTI_USER.md §3.3) ──
    # The identity the request/job pool connects as. It is deliberately NOT a
    # superuser and NOT the table owner, because a superuser BYPASSES Row-Level
    # Security unconditionally (`rolbypassrls`) — RLS policies added on top of a
    # superuser connection are decoration, not isolation.
    #
    # Blank ⇒ the pool falls back to the admin creds above, i.e. exactly the
    # pre-split behaviour, so this change is safe to deploy BEFORE the role is
    # provisioned. The fallback is not silent: `core/db` logs a prominent WARNING
    # naming the over-privileged role at pool open. Provision the role with
    # `python -m healthee.db.provision_app_role` (run as the admin), then set these.
    postgres_app_user: str = ""
    postgres_app_password: str = ""

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

    # ── Entitlement (Phase 6.6a, MULTI_USER.md §12) ───────────────────────
    # Declares that this deployment is somebody's OWN box, so every owner on it gets
    # the AI layer without a `subscription` row. Default false: the hosted service
    # must never be unlocked by forgetting to set something.
    #
    # It exists because the paywall's whole justification is OUR LLM bill on OUR
    # hosted service (PRICING.md §6.1) — an argument that does not survive contact
    # with a self-hoster running their own OpenRouter key, which is the product's
    # stated brand. The server cannot tell the two deployments apart, so the operator
    # says which one it is; that is server-owned config, not a client claim, and it is
    # exactly §12.6 step (a)'s "admin/config flag". It is logged at startup by both
    # the API and the scheduler, so a hosted box that sets it by accident says so on
    # every boot rather than quietly giving the AI layer away.
    self_host_unlocked: bool = False
    # Where a locked card sends someone. Carried in the 402 body and by
    # `/api/entitlement` so the upgrade destination is deployment config rather than a
    # URL compiled into the app — a self-hoster has no checkout page to point at, and
    # the hosted one's moves when [D4] is decided.
    upgrade_url: str = ""

    # ── OpenRouter (optional — grounded LLM insights, wired in a later WP) ─
    openrouter_api_key: str = ""
    # LLM model ids — kept in env (DEFAULT_MODEL / COACH_MODEL), NOT hardcoded, so the
    # source never reveals which models we run. Blank here (nothing leaked to git);
    # real values live in the deploy env / a local .env. default_model = the cheap
    # high-volume tier; coach_model = the stronger tier for the interactive coach.
    # Blank is legal ONLY while the key above is blank too — `_require_model_ids_when_
    # ai_key_is_set` below refuses the half-configured state, which is a dead AI layer
    # behind a green /healthz.
    default_model: str = ""
    coach_model: str = ""
    # How long ONE LLM HTTP call may take before it is abandoned, and how many times
    # the SDK may retry it. Both are explicit because the SDK's defaults are
    # catastrophic here: `openai` defaults to a 600 s read timeout with 2 retries, so
    # a single stuck call can hang for 3 × 600 s = 30 MINUTES. Since 6.4c the
    # scheduler is a single-threaded tick loop iterating `active_users()`, so that one
    # call blocks EVERY later owner's chain for half an hour — silently, because the
    # tick that would have run them is simply still waiting.
    #
    # 60 s: the default tier is a Flash-class model that answers an ~8k-in/700-out
    # prompt in seconds (PRICING.md §3.1), so this is ~10× the expected worst case —
    # generous enough that a slow-but-fine call still returns (too tight would convert
    # them into failures and empty cards, which is the honesty cost of over-tuning),
    # and short enough that a hang is a hang. Nothing here is latency-sensitive: the
    # warm/recs/briefing surfaces are all off the read path, so the number only has to
    # bound the damage.
    # 1 retry: retries MULTIPLY the timeout, which is what turns a bad call into an
    # outage — the SDK's 2 keep the worst case at 3 × 60 s = 3 min, one keeps it at
    # 2 min while preserving recovery from a transient 429/5xx. The scheduler's own
    # `_ATTEMPT_BUDGET` and tomorrow's tick are the outer retries.
    llm_timeout_s: float = 60.0
    llm_max_retries: int = 1
    # Dollars remaining on the OpenRouter account below which the scheduler's watcher
    # warns (`jobs.llm_watch`, read through `insights.credits.balance_state`). It is a
    # WARNING line, never a refusal — nothing in the app declines to spend because of
    # it, because a health companion going quiet on its own is the failure mode this
    # product exists to avoid.
    #
    # 20 is roughly a fortnight of the measured spend at one owner (PRICING.md §3.1's
    # box: ~$22 on the day the eval harness and production shared a key). Set it to a
    # multiple of YOUR daily spend, not of the balance: the number that matters is how
    # many days of warning it buys. 0 disables the warning and leaves only the
    # `exhausted` alert, which is the one that fires when it is already too late.
    llm_low_balance_usd: float = 20.0

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

    @model_validator(mode="after")
    def _require_app_creds_together(self) -> Self:
        """App user and password are both-or-neither — never one alone.

        Half-set creds are the dangerous case: the pool would either try a
        passwordless login or connect as the ADMIN while the operator believes the
        least-privilege role is in force. Both failure modes are silent, and the
        second one is the exact security theatre this split exists to end. Refuse
        the ambiguity instead of picking an interpretation.
        """
        if bool(self.postgres_app_user) != bool(self.postgres_app_password):
            raise ValueError(
                "POSTGRES_APP_USER and POSTGRES_APP_PASSWORD must be set together "
                "(set both to use the least-privilege app role, or neither to fall "
                "back to the admin creds)"
            )
        return self

    @model_validator(mode="after")
    def _require_model_ids_when_ai_key_is_set(self) -> Self:
        """Refuse "configured for AI, but cannot do AI" — it is never a valid state.

        A blank model id is not a default, it is a dead subsystem: the id is forwarded
        to OpenRouter verbatim and comes back **400 on every call** — insight cards,
        the coach, and the nightly recs/briefing chain. Nothing in the deploy can see
        it. `/healthz` is a liveness+DB probe, so it goes green; the LLM failures land
        in Telegram and the scheduler log. Prod ran in exactly this state.

        **Fail fast, not warn.** `core/db._warn_if_privileged` is the right precedent
        for the *other* shape of problem — the admin-creds fallback is a documented,
        deliberately-transitional step of a two-deploy bootstrap (`infra/DEPLOY.md`
        §B2), so it must stay bootable. There is no deploy order, no bootstrap and no
        migration in which "key set, model id blank" is correct, which makes it the
        same shape as `_require_app_creds_together` above: an ambiguity to refuse, not
        an interpretation to pick. Refusing turns it into a *deploy-time* failure, in
        front of the operator, instead of a silence discovered weeks later.

        Not running the AI layer stays a first-class, bootable configuration: leave
        `OPENROUTER_API_KEY` blank and this never fires. The check only triggers on a
        state the operator explicitly asked for and then half-configured.

        Deliberately NOT mirrored into `/healthz`: with this validator the state cannot
        exist in a live process, and a probe that 503s on a config problem would let
        Docker's healthcheck restart the container into the same config forever —
        trading a dead AI layer for a flapping read API, which is worse than the
        disease. Config correctness belongs at boot; `/healthz` stays a signal an
        orchestrator can act on.
        """
        if not self.openrouter_api_key:
            return self
        blank = [
            name
            for name, value in (
                ("DEFAULT_MODEL", self.default_model),
                ("COACH_MODEL", self.coach_model),
            )
            if not value.strip()
        ]
        if blank:
            raise ValueError(
                f"OPENROUTER_API_KEY is set but {' and '.join(blank)} is blank — a blank "
                "model id reaches OpenRouter verbatim and every LLM call returns 400, "
                "with nothing failing in /healthz. Set the model id(s), or unset "
                "OPENROUTER_API_KEY to run without the AI layer."
            )
        return self

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
    def app_role_configured(self) -> bool:
        """True when a dedicated least-privilege app role is configured.

        False ⇒ the pool falls back to the admin creds (`core/db` warns).
        """
        return bool(self.postgres_app_user)

    def _conninfo(self, user: str, password: str) -> str:
        """libpq connection string for one identity — the ONE place it is formatted."""
        return (
            f"host={self.postgres_host} port={self.postgres_port} "
            f"dbname={self.postgres_db} user={user} password={password}"
        )

    @property
    def app_db_url(self) -> str:
        """Conninfo for the APPLICATION pool (`core/db.get_pool`).

        The least-privilege role when configured, else the admin creds — the
        backwards-compatible fallback, which `core/db` announces with a WARNING.
        """
        if self.app_role_configured:
            return self._conninfo(self.postgres_app_user, self.postgres_app_password)
        return self.admin_db_url

    @property
    def admin_db_url(self) -> str:
        """Conninfo for the OWNER/ADMIN identity — DDL, TRUNCATE, re-keying.

        Only `core/db.admin_connection()` may use this; see its docstring for who
        is allowed to call it and why.
        """
        return self._conninfo(self.postgres_user, self.postgres_password)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return the process-wide Settings singleton, constructing it on first call.

    Cached so every caller shares one instance. `get_settings.cache_clear()` in a
    test fixture forces a re-read after patching the environment.
    """
    return Settings()
