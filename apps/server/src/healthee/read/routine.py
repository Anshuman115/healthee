"""What the owner actually did today: open fast, meditation, workouts, manual logs.

Split out of ``read/recovery.py`` (which had grown to four unrelated payloads): this
is the Today page's activity/routine roll-up, not a recovery signal, and it has its
own reason to change. All v2-native reads over ``manual_entry`` / ``workout``, on the
caller's RLS-scoped cursor.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

from healthee.core.tenancy import user_today
from healthee.derive._common import Cur
from healthee.read.common import sport_name


def routine_today(cur: Cur, user_id: UUID, tz: str) -> dict:
    """Open fast + today's meditation, workouts, and manual-log counts."""
    return {
        "open_fast": _open_fast(cur, user_id),
        "meditation_today": _meditation_today(cur, user_id, tz),
        "workouts": _workouts_today(cur, user_id, tz),
        "logs_summary": _logs_summary(cur, user_id, tz),
    }


def _open_fast(cur: Cur, user_id: UUID) -> dict | None:
    cur.execute(
        "SELECT id, ts FROM manual_entry WHERE user_id = %s AND kind='fasting' "
        "AND end_ts IS NULL ORDER BY ts DESC LIMIT 1",
        (user_id,),
    )
    row = cur.fetchone()
    if not row:
        return None
    elapsed = int((datetime.now(tz=UTC) - row[1]).total_seconds() // 60)
    return {"id": str(row[0]), "start_iso": row[1].isoformat(), "elapsed_min": elapsed}


def _meditation_today(cur: Cur, user_id: UUID, tz: str) -> dict:
    cur.execute(
        "SELECT COUNT(*), COALESCE(SUM(amount),0) FROM manual_entry "
        "WHERE user_id = %s AND kind='meditation' AND (ts AT TIME ZONE %s)::date = %s",
        (user_id, tz, user_today(tz)),
    )
    c, m = cur.fetchone() or (0, 0)
    return {"count": int(c or 0), "minutes": int(m or 0)}


def _workouts_today(cur: Cur, user_id: UUID, tz: str) -> list[dict]:
    """Today's device workouts (>=10 min), newest first."""
    cur.execute(
        "SELECT start_ts, duration_s, sport FROM workout WHERE user_id = %s "
        "AND (start_ts AT TIME ZONE %s)::date = %s AND COALESCE(duration_s,0) >= 600 "
        "ORDER BY start_ts DESC",
        (user_id, tz, user_today(tz)),
    )
    out = []
    for start_ts, dur_s, sport in cur.fetchall():
        dur_min = round((dur_s or 0) / 60) if dur_s else None
        end_iso = (start_ts + timedelta(seconds=int(dur_s or 0))).isoformat() if start_ts else None
        out.append(
            {
                "kind": "workout",
                "type": sport_name(sport),
                "start_iso": start_ts.isoformat() if start_ts else None,
                "end_iso": end_iso,
                "duration_min": dur_min,
                "intensity": None,
                "source": "strap",
            }
        )
    return out


def _logs_summary(cur: Cur, user_id: UUID, tz: str) -> dict:
    cur.execute(
        "SELECT kind, COUNT(*), COALESCE(SUM(amount),0) FROM manual_entry "
        "WHERE user_id = %s AND (ts AT TIME ZONE %s)::date = %s GROUP BY kind",
        (user_id, tz, user_today(tz)),
    )
    return {k: {"count": int(c), "total": float(t or 0)} for k, c, t in cur.fetchall()}
