"""Daily manual-log markers for the bounded metric-history chart."""

from datetime import timedelta
from uuid import UUID

from healthee.core.tenancy import user_today
from healthee.derive._common import Cur


def history_logs(cur: Cur, user_id: UUID, tz: str, days: int) -> dict:
    today = user_today(tz)
    cur.execute(
        "SELECT day, kind, count(*) FROM (SELECT (ts AT TIME ZONE %s)::date AS day, kind "
        "FROM manual_entry WHERE user_id = %s AND kind IN "
        "('caffeine', 'alcohol', 'meditation', 'exercise')) AS entries "
        "WHERE day >= %s AND day <= %s GROUP BY day, kind ORDER BY day, kind",
        (tz, user_id, today - timedelta(days=days - 1), today),
    )
    return {
        "markers": [
            {"day": day.isoformat(), "kind": kind, "count": count}
            for day, kind, count in cur.fetchall()
        ]
    }
