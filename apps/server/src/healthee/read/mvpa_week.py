"""Moderate-to-vigorous minutes for the week containing a day — the ONE definition.

Two surfaces report this number and they used to be one implementation and one hole:
``read/fitness.py::mvpa_payload`` computed it for ``/api/activity.mvpa.week_min``, and
``read/vo2max.py`` shipped ``inputs.weekly_mvpa_min`` hardcoded ``None`` beside a comment
saying v2 does not store it in the VO₂max flags. Both statements were true and together
they were a gap: the number was not stored, but it *was* computed, twenty lines away, off
the same ``derived_daily`` rows.

Filling that hole by re-summing the week inside ``read/vo2max.py`` would have been the
second definition CLAUDE.md forbids — two answers to "how many MVPA minutes this week",
free to drift on a Monday-vs-Sunday week start or on whether the reference day counts.
And it could not have been an import either: ``read/fitness.py`` imports
``vo2max_payload``, so the arrow only points one way. Hence a module both may depend on.

Everything here is a MEASURED sum over stored rows. Nothing is defaulted: an owner with
no ``mvpa_min`` rows in the window gets ``None`` — not a zero, which would read as a week
of measured stillness rather than as a week we cannot account for.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from uuid import UUID

from healthee.core.tenancy import AS_OF_DAY_SQL
from healthee.derive._common import Cur

# A week's worth of days plus the day itself: the reference day's week starts at most six
# days before it, so eight days always covers the week and gives the daily breakdown one
# day of lead-in.
WEEK_WINDOW_DAYS = 8


@dataclass(frozen=True)
class MvpaWeek:
    """MVPA minutes for the week containing a reference day, and that day's own.

    ``week_start`` is the Monday of the week CONTAINING the reference day, and the week
    stops at the reference day: a Wednesday in June reports Monday-to-Wednesday, never
    the whole June week seen from August (``docs/AS_OF_DAY.md`` section 3).

    ``moderate_min`` and ``vigorous_min`` are ``None`` when any day in the week carries an
    ``mvpa_min`` row WITHOUT the intensity breakdown in its flags. The split used to be
    coalesced to zero in SQL, so a day whose breakdown was never recorded contributed zero
    moderate and zero vigorous minutes to a total presented as measured — the flag-level
    twin of the row-level absence this module is careful about two functions down.
    ``mvpa_min`` itself is a stored value and is always a real sum.
    """

    week_start: date
    moderate_min: int | None
    vigorous_min: int | None
    mvpa_min: int
    on_day_min: int
    daily: list[dict]


def weekly_mvpa_rows(cur: Cur, user_id: UUID, as_of: date, days: int) -> list[tuple]:
    """(day, moderate, vigorous, mvpa) for the ``days`` days ENDING at ``as_of``.

    ``moderate`` / ``vigorous`` come from the ``mvpa_min`` row's flags — v2 stores them
    there rather than as rows of their own (the WP6 seam fix) — and are **None** when the
    row carries no breakdown. They were coalesced to 0 in SQL, which is the same
    absence-as-zero the module docstring warns about, one level down: the row-level gap was
    honoured and the flag-level gap was filled in with a number nobody measured. It reached
    ``/api/activity.mvpa.week_moderate_min``, every entry of ``daily``, and
    ``fitness_plan_payload``'s ``zone2_done_min`` / ``vilpa_done_min``.
    """
    cur.execute(
        "SELECT day, (flags->>'moderate')::float, "
        "(flags->>'vigorous')::float, value FROM derived_daily "
        f"WHERE user_id = %s AND metric='mvpa_min' AND day > ({AS_OF_DAY_SQL} - %s::int) "
        f"AND day <= {AS_OF_DAY_SQL} ORDER BY day",
        (user_id, as_of, days, as_of),
    )
    return cur.fetchall()


def mvpa_week(cur: Cur, user_id: UUID, as_of: date) -> MvpaWeek | None:
    """The week-to-date MVPA totals as of ``as_of``, or ``None`` with nothing to sum.

    ``None`` rather than a zeroed record, and the distinction is the point: an owner
    whose strap has written no ``mvpa_min`` row in the window has not been measured as
    still, they have not been measured. Callers surface that as an absence with a
    reason, never as ``0``.
    """
    rows = weekly_mvpa_rows(cur, user_id, as_of, WEEK_WINDOW_DAYS)
    if not rows:
        return None
    monday = as_of - timedelta(days=as_of.weekday())
    daily: list[dict] = []
    week_mod = week_vig = week_mvpa = on_day = 0
    # One day in the week with no recorded breakdown makes the WEEK's split unknowable, not
    # smaller: summing the days that have one and presenting the result as the week's total
    # would understate it by exactly the days nobody measured, with nothing on the wire
    # saying which. The total `mvpa_min` is unaffected — that is a stored value per day.
    split_measured = True
    for d, moderate, vigorous, mvpa in rows:
        mv_i = int(mvpa)
        m_i = int(moderate) if moderate is not None else None
        v_i = int(vigorous) if vigorous is not None else None
        daily.append(
            {"date": d.isoformat(), "moderate_min": m_i, "vigorous_min": v_i, "mvpa_min": mv_i}
        )
        if d >= monday:
            week_mvpa += mv_i
            if m_i is None or v_i is None:
                split_measured = False
            else:
                week_mod, week_vig = week_mod + m_i, week_vig + v_i
        if d == as_of:
            on_day = mv_i
    return MvpaWeek(
        week_start=monday,
        moderate_min=week_mod if split_measured else None,
        vigorous_min=week_vig if split_measured else None,
        mvpa_min=week_mvpa,
        on_day_min=on_day,
        daily=daily,
    )
