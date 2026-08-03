"""Which OpenRouter key a paid arm spends — and saying so out loud when it is prod's.

On 2026-08-01 this harness drained the shared account and every production LLM call 402'd
for hours behind a green ``/healthz`` (``infra/DEPLOY.md`` §E1). The fix named there has
two halves: a credit limit on each key, and a **separate eval key** so a drained eval
costs an eval run rather than the live AI layer. The account half is the owner's to do —
a key cannot be minted from here.

What this module does is the half that *is* code, and it is deliberately not a gate:

- ``EVAL_OPENROUTER_API_KEY`` set  → the arm spends that key, and says which one it used.
- unset                           → the arm still runs, on ``OPENROUTER_API_KEY``, after a
                                    loud warning that names the risk and the balance it is
                                    spending. Nothing breaks today; nobody spends prod's
                                    credit on a 105-run arm without having been told.
- both unset                      → nothing to say here. ``insights/client`` already
                                    raises "OPENROUTER_API_KEY is unset" at first use, and
                                    duplicating that check would only make it ambiguous
                                    which layer refused.

The override works by rewriting ``OPENROUTER_API_KEY`` in the process environment and
dropping the settings cache, because the client resolves its key from
``get_settings().openrouter_api_key`` and there is no per-call seam for it. That keeps the
production code path completely untouched by a test-only concern — the harness is a
caller, not a special case.

Only the ``run`` subcommand calls this. ``compare`` spends nothing and must stay silent.
"""

from __future__ import annotations

import os
import sys

from healthee.core.config import get_settings

EVAL_KEY_VAR = "EVAL_OPENROUTER_API_KEY"
PROD_KEY_VAR = "OPENROUTER_API_KEY"

_WARNING = f"""
⛔ NO EVAL KEY — this arm will spend the PRODUCTION OpenRouter key.
   {EVAL_KEY_VAR} is unset, so the harness fell back to {PROD_KEY_VAR}.
   An arm costs ~$3. This harness is what emptied the shared account on 2026-08-01,
   after which every production LLM call 402'd for hours behind a green /healthz.
   Draining it again takes the coach, the insight cards and the nightly chain down.
   Fix (owner, ~2 minutes): openrouter.ai → Keys → create a key with a small credit
   limit, then put it in apps/server/.env as {EVAL_KEY_VAR}=sk-or-...
   Reasoning and the account-side steps: infra/DEPLOY.md §E2.
"""


def _mask(key: str) -> str:
    """A key rendered so two keys are distinguishable and neither is disclosed.

    Standards §Errors: no secret reaches a log line. The prefix is not secret (every
    OpenRouter key starts ``sk-or-v1-``), so only the length is reported after it.
    """
    return f"{key[:9]}…({len(key)} chars)" if len(key) > 9 else "…(short)"


def select_api_key() -> str:
    """Point the LLM client at the eval key when there is one; warn loudly when there is not.

    Returns which key the arm will spend — ``"eval"``, ``"production"``, or ``"unset"`` —
    so a caller (and the test suite) can assert on the choice rather than on stderr.
    """
    eval_key = os.environ.get(EVAL_KEY_VAR, "").strip()
    if eval_key:
        os.environ[PROD_KEY_VAR] = eval_key
        get_settings.cache_clear()  # the client resolves its key through this cache
        print(f"eval key: {EVAL_KEY_VAR} = {_mask(eval_key)} — production credit is safe\n")
        return "eval"

    if not os.environ.get(PROD_KEY_VAR, "").strip():
        return "unset"  # client.get_client() raises on first use; one refusal, not two

    print(_WARNING, file=sys.stderr, flush=True)
    return "production"
