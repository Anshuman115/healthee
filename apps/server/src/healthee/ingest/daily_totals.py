"""The strap's own since-midnight counters, stored RAW (#121) with both instants (0019).

Split out of ``ingest/upsert.py``: that module is "turn a validated payload into rows",
and this is the one section of it with a second reason to change — the counter has a
precedence question (``derive/device_totals.py``), a partial-day disclosure, and a
regression question of its own, and the arguments for each live here beside the write.

Nothing in this module produces a metric. It stores what the device said; the day pass
decides what ``steps_total`` becomes from it. That separation IS #121's fix.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.ingest.models import DailyTotalIn
from healthee.ingest.upsert import Cur, epoch_to_utc

log = get_logger(__name__)


def upsert_daily_totals(cur: Cur, user_id: UUID, totals: list[DailyTotalIn]) -> int:
    """Store the strap's live 0x0016 daily totals RAW, as reported. Returns rows stored.

    ## What this replaced, and why the replacement is a different KIND of thing (#121)

    This used to be `apply_daily_totals`, which wrote the strap's counter straight into
    `derived_daily.steps_total` (and `distance_m_daily`) and nowhere else, under a
    docstring that said it "MUST run AFTER derive … the strap counter is authoritative".
    Both halves of that were true and together they were the bug: `derived_daily` is
    exactly what a derive pass REBUILDS, so the next derive over that day — a push
    carrying one late sample, a `db/rederive` repair, a backfill — recomputed
    `steps_total` from the per-minute sum and the device's own count was gone, with no
    raw row anywhere to restore it from. Production held 142 days of the per-minute sum
    and one day of the strap counter for exactly that reason.

    So this function no longer produces a metric at all. It stores a measurement, in
    `device_daily_total`, and `derive/device_totals.py` decides what `steps_total` is.
    The ordering constraint is therefore gone rather than moved: this runs before derive
    for the same reason `upsert_samples` does — raw first, then derivation — and if it
    ever ran after, the next derive pass would pick the row up instead of the value being
    destroyed. Correctness stopped depending on the order.

    A later report for the same day REPLACES an earlier one: the counter is a live
    since-midnight accumulator, so the newest reading is the most complete one. Rows that
    carry no number at all are skipped — a payload entry with every field null is not a
    measurement — but a report with only distance, or only calories, is stored: this
    table's job is to hold what the device said, and the derivation reads each field
    independently.

    ## Two instants, and why `read_at` is ASSIGNED rather than COALESCEd (audit A1)

    `reported_at` is when the report ARRIVED. `read_at` (0019) is when the phone ASKED the
    strap, which is the instant the counter is actually a claim about, and it is the one
    :func:`derive.device_totals.partial_day_caveats` reads. Before 0019 there was one
    column doing both jobs and the caveat quoted the wrong quantity.

    `read_at` follows the report, not the row: a newer report that does not say when it
    was read leaves the row saying **unknown**, because an older read instant attached to
    a newer counter would assert that this larger number was read at that earlier moment —
    the same fabrication in a smaller shape. Losing a fact is not the same as inventing
    one, and only one of the two is recoverable by the next sync.

    ## A regressing counter is LOGGED, and not guarded — the decision, with its evidence

    A since-midnight accumulator resets on a device reboot or a clock change, and the next
    reading is then LOWER. It is written, and the higher one is gone: one row per
    `(user_id, day)`, no history. Audit B6 raises this as SUSPECTED and it stays that way,
    because it is a statement about firmware that needs the strap to settle.

    The write is deliberately NOT made monotone. `GREATEST` looks like the safe choice and
    is not: this is the RAW table, and #121's whole lesson is that raw rows hold what the
    device said and derivations decide what to serve from them. A maximum is a derivation,
    it would pin a single spurious high reading forever, and on a genuine reset it would
    keep the pre-reset prefix while claiming — through `read_at` — to have been read at
    the later instant. Making it fully honest instead needs a row per reading, i.e. a
    different primary key, which is a real migration for a condition nobody has yet
    observed.

    So the assumption stops being unstated and starts being falsifiable: a lower reading
    replacing a higher one is a WARNING naming both values, so the next time it happens
    there is evidence instead of speculation. One extra indexed read per push pays for it.
    """
    rows = [
        (user_id, t.day, t.steps, t.distance_m, t.calories, _read_instant(t))
        for t in totals
        if t.steps is not None or t.distance_m is not None or t.calories is not None
    ]
    if rows:
        _warn_on_regressed_counters(cur, user_id, totals)
        cur.executemany(
            "INSERT INTO device_daily_total "
            "(user_id, day, steps, distance_m, calories, read_at, reported_at) "
            "VALUES (%s, %s, %s, %s, %s, %s, now()) "
            # COALESCEd per field: a report carrying only distance must not blank the
            # step count the same day already had. The table's own docstring says "the
            # derivation reads each field independently", and a plain assignment made
            # that untrue on the write side. `reported_at` and `read_at` ARE assigned —
            # they date this report, and the newest report is the one that arrived.
            "ON CONFLICT (user_id, day) DO UPDATE SET "
            "steps = COALESCE(EXCLUDED.steps, device_daily_total.steps), "
            "distance_m = COALESCE(EXCLUDED.distance_m, device_daily_total.distance_m), "
            "calories = COALESCE(EXCLUDED.calories, device_daily_total.calories), "
            "read_at = EXCLUDED.read_at, "
            "reported_at = EXCLUDED.reported_at",
            rows,
        )
    return len(rows)


def _read_instant(total: DailyTotalIn) -> datetime | None:
    """When the phone asked the strap, or ``None`` when this client did not say.

    Absent stays absent all the way to the column. The one thing this must never do is
    substitute an instant it can reach — `now()`, the arrival, the day's end — because a
    reader cannot then tell a recorded read time from a manufactured one, which is the
    whole of audit A1.
    """
    return None if total.read_at is None else epoch_to_utc(total.read_at)


def _warn_on_regressed_counters(cur: Cur, user_id: UUID, totals: list[DailyTotalIn]) -> None:
    """Log any day whose stored step counter is HIGHER than the reading about to replace it.

    See :func:`upsert_daily_totals` for why this warns rather than guards. One query for
    the whole batch, keyed on the primary key, so the cost is one indexed round-trip.
    """
    incoming = {t.day: t.steps for t in totals if t.steps is not None}
    if not incoming:
        return
    cur.execute(
        "SELECT day, steps FROM device_daily_total "
        "WHERE user_id = %s AND day = ANY(%s) AND steps IS NOT NULL",
        (user_id, list(incoming)),
    )
    for day, stored in cur.fetchall():
        if incoming[day] < int(stored):
            log.warning(
                "device_daily_total counter regressed",
                extra={
                    "user_id": str(user_id),
                    "day": str(day),
                    "stored_steps": int(stored),
                    "incoming_steps": incoming[day],
                },
            )
