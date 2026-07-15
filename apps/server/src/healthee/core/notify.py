"""Outbound notifications — Telegram, for job status and failures.

One sink: `send_telegram(text)`. It is fire-and-forget by contract and **must
never raise into its caller** — a failed notification cannot be allowed to break
the pipeline it reports on. Every failure is logged with context (standards §1:
failures are logged through the one logging path, never silently swallowed) and
returns `False`; success returns `True`.

Unconfigured (no bot token / chat id) is not a failure — it logs at debug and
no-ops, so callers don't have to gate on config.
"""

from __future__ import annotations

import httpx

from healthee.core.config import get_settings
from healthee.core.logging import get_logger

log = get_logger(__name__)

_API_BASE = "https://api.telegram.org"
_TIMEOUT_S = 10.0


def send_telegram(text: str, *, silent: bool = False) -> bool:
    """POST one message to the configured Telegram chat. Returns True on success.

    Returns False (logging why) on any failure or when notifications aren't
    configured. Never raises.
    """
    settings = get_settings()
    token = settings.telegram_bot_token.strip()
    chat_id = settings.telegram_chat_id.strip()
    if not token or not chat_id:
        log.debug("telegram not configured — skipping notification")
        return False

    url = f"{_API_BASE}/bot{token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
        "disable_notification": silent,
        "disable_web_page_preview": True,
    }
    try:
        response = httpx.post(url, json=payload, timeout=_TIMEOUT_S)
    except httpx.HTTPError as exc:
        log.warning("telegram send failed (network): %s", exc)
        return False
    except Exception as exc:  # last-resort guard — notify must never raise
        log.warning("telegram send failed (unexpected): %s", exc)
        return False

    if response.is_success:
        return True
    log.warning("telegram HTTP %d: %s", response.status_code, response.text[:200])
    return False
