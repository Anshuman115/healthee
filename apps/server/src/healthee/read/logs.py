"""Manual logging — write (``POST /api/log``) and read (``GET /api/log/recent``).

v2-native writes to ``manual_entry`` / ``weight_log`` (the schema's own tables — no
v1 ``session`` view). Ported from legacy ``_record_log`` / ``log_recent`` with the
swallowed try/except removed: business-rule outcomes return an explicit
``{"ok": False, ...}``; a genuine DB failure propagates (standards §Errors).
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

from pydantic import BaseModel

from healthee.derive._common import Cur

# Instant kinds (a point event with an amount) vs the two duration kinds.
_INSTANT_KINDS = frozenset(
    {"caffeine", "alcohol", "water", "food", "med", "symptom", "mood", "habit"}
)
_DURATION_KINDS = frozenset({"meditation", "exercise"})


class LogRequest(BaseModel):
    """Body of ``POST /api/log`` (mirrors the legacy ``_LogRequest``)."""

    type: str
    amount: float | None = None
    name: str | None = None
    unit: str | None = None
    minutes: int | None = None
    kind: str | None = None
    at: int | None = None  # epoch ms; None = now
    notes: str | None = None


def record_log(cur: Cur, user_id: UUID, req: LogRequest) -> dict:
    """Write one manual log owned by ``user_id``. Returns ``{"ok": True}`` (with
    optional ``discarded``) or an explicit ``{"ok": False, "error": ...}`` for a
    rule outcome."""
    ts = datetime.fromtimestamp(req.at / 1000, tz=UTC) if req.at else datetime.now(tz=UTC)
    t = req.type
    if t == "weight":
        cur.execute(
            "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, %s) "
            "ON CONFLICT (user_id, ts) DO UPDATE SET kg = EXCLUDED.kg",
            (user_id, ts, float(req.amount or 0)),
        )
    elif t in _INSTANT_KINDS:
        cur.execute(
            "INSERT INTO manual_entry (user_id, kind, ts, name, amount, unit, notes) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s)",
            (user_id, t, ts, req.name, req.amount, req.unit, req.notes),
        )
    elif t in _DURATION_KINDS:
        mins = int(req.minutes or 0)
        cur.execute(
            "INSERT INTO manual_entry (user_id, kind, ts, end_ts, name, amount, unit, notes) "
            "VALUES (%s,%s,%s,%s,%s,%s,'min',%s)",
            (user_id, t, ts - timedelta(minutes=mins), ts, req.kind, mins, req.notes),
        )
    elif t in ("fast_start", "fast_end"):
        return _record_fast(cur, user_id, t, ts, req.notes)
    else:
        return {"ok": False, "error": f"unknown log type {t}"}
    return {"ok": True}


def _record_fast(cur: Cur, user_id: UUID, t: str, ts: datetime, notes: str | None) -> dict:
    """Open/close a fasting entry (one open fast at a time; discard <5-min accidents)."""
    if t == "fast_start":
        cur.execute(
            "SELECT 1 FROM manual_entry WHERE user_id=%s AND kind='fasting' "
            "AND end_ts IS NULL LIMIT 1",
            (user_id,),
        )
        if cur.fetchone():
            return {"ok": False, "error": "a fast is already open"}
        cur.execute(
            "INSERT INTO manual_entry (user_id, kind, ts, notes) VALUES (%s, 'fasting', %s, %s)",
            (user_id, ts, notes),
        )
        return {"ok": True}
    cur.execute(
        "SELECT ts FROM manual_entry WHERE user_id=%s AND kind='fasting' AND end_ts IS NULL "
        "ORDER BY ts DESC LIMIT 1",
        (user_id,),
    )
    open_row = cur.fetchone()
    if open_row and (ts - open_row[0]).total_seconds() < 300:
        cur.execute(
            "DELETE FROM manual_entry WHERE user_id=%s AND kind='fasting' AND end_ts IS NULL",
            (user_id,),
        )
        return {"ok": True, "discarded": "fast under 5 minutes — not recorded"}
    cur.execute(
        "UPDATE manual_entry SET end_ts=%s WHERE user_id=%s AND kind='fasting' AND end_ts IS NULL",
        (ts, user_id),
    )
    return {"ok": True}


def log_recent(cur: Cur, user_id: UUID, days: int = 7) -> dict:
    """Recent manual logs + current fasting status (the log feed)."""
    entries: list[dict] = []
    cur.execute(
        "SELECT kind, ts, name, amount, unit, notes FROM manual_entry "
        "WHERE user_id = %s AND kind <> 'fasting' AND ts >= now() - (%s || ' days')::interval "
        "ORDER BY ts DESC LIMIT 80",
        (user_id, days),
    )
    for k, ts, name, amount, unit, notes in cur.fetchall():
        entries.append(
            {
                "type": k,
                "ts": int(ts.timestamp() * 1000),
                "name": name,
                "amount": float(amount) if amount is not None else None,
                "unit": unit,
                "notes": notes,
            }
        )
    cur.execute(
        "SELECT ts, kg FROM weight_log WHERE user_id = %s ORDER BY ts DESC LIMIT 1", (user_id,)
    )
    wr = cur.fetchone()
    if wr:
        entries.append(
            {
                "type": "weight",
                "ts": int(wr[0].timestamp() * 1000),
                "amount": float(wr[1]),
                "unit": "kg",
            }
        )
    entries.sort(key=lambda e: e["ts"], reverse=True)
    return {"entries": entries, "fast": _fast_status(cur, user_id)}


def _fast_status(cur: Cur, user_id: UUID) -> dict:
    cur.execute(
        "SELECT ts FROM manual_entry WHERE user_id = %s AND kind='fasting' AND end_ts IS NULL "
        "ORDER BY ts DESC LIMIT 1",
        (user_id,),
    )
    r = cur.fetchone()
    if not r:
        return {"open": False}
    mins = int((datetime.now(tz=UTC) - r[0]).total_seconds() // 60)
    return {"open": True, "current": {"duration_min": mins}}
