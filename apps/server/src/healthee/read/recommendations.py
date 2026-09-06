"""Dated action history and explicit, reversible adoption state."""

from datetime import timedelta
from uuid import UUID

from healthee.core.tenancy import user_today
from healthee.derive._common import Cur


def recommendation_shape(row: tuple) -> dict:
    return dict(
        zip(
            (
                "id",
                "date",
                "rank",
                "action",
                "rationale",
                "expected_effect",
                "category",
                "evidence_grade",
                "research_note_ids",
                "signal_source",
                "adopted",
            ),
            (row[0], row[1].isoformat(), *row[2:8], list(row[8] or []), row[9], row[10]),
            strict=True,
        )
    )


def history(cur: Cur, user_id: UUID, tz: str, days: int, offset: int) -> list[dict]:
    cur.execute(
        "SELECT id, date, rank, action, rationale, expected_effect, category, evidence_grade, "
        "research_note_ids, signal_source, adopted FROM recommendation "
        "WHERE user_id = %s AND date >= %s AND date <= %s "
        "ORDER BY date DESC, rank ASC, id DESC LIMIT 100 OFFSET %s",
        (user_id, user_today(tz) - timedelta(days=days - 1), user_today(tz), offset),
    )
    return [recommendation_shape(row) for row in cur.fetchall()]


def set_adoption(cur: Cur, user_id: UUID, rec_id: int, adopted: bool) -> bool:
    cur.execute(
        "UPDATE recommendation SET adopted = %s, adopted_at = CASE WHEN %s "
        "THEN now() ELSE NULL END WHERE user_id = %s AND id = %s RETURNING id",
        (adopted, adopted, user_id, rec_id),
    )
    return cur.fetchone() is not None
