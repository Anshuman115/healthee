"""ONE ``steps_total`` (and ``distance_m_daily``), two instruments, a stated precedence.

## The defect this module closes (#121)

The strap reports its own since-midnight step counter on BLE 0x0016. Until #121 the
ingest path wrote that number **straight into ``derived_daily.steps_total``** after the
derive pass had run, with ``flags.source = 'strap_0x16'`` — and stored it nowhere else.
``derived_daily`` is the table a derive pass rebuilds, so the next derive over that day
recomputed ``steps_total`` from the per-minute ``steps_per_minute`` sum and the device's
count was gone. There was no raw row to restore it from, so the loss was permanent.

Measured on production 2026-08-02: of 143 ``steps_total`` rows, **142 carried the
per-minute sum and one carried ``strap_0x16``**. The per-minute stream is the one our own
code called "possibly frozen/incomplete", and it demonstrably stalls (the 0xFF-gap pager
stall is why the override was written at all). We served the worse number on 142 days out
of 143 while discarding the better one.

⛔ **Those 142 days are not recovered.** ``device_daily_total`` starts empty and nothing
backfills it, because there is nothing to backfill from — the strap's numbers for those
days existed only in the overwritten cell, and the pre-repair production backups hold the
same overwritten values. This module fixes the loss going forward only.

## The precedence, and the one place it lives

    1. SOURCE_DEVICE      — the strap's own daily counter (``device_daily_total``)
    2. SOURCE_PER_MINUTE  — the sum of ``steps_per_minute`` samples over the local day

The device counter wins because the two instruments fail differently and only one of them
fails silently: the per-minute stream drops whole stretches when the pager stalls, and a
day with a stalled hour looks exactly like a quiet hour. The device's accumulator is the
same sensor's own running total and is not affected by how the samples were paged off it.

**No blending, and structurally so.** Nothing here adds, averages or maxes the two
numbers. :func:`select_steps` returns ONE instrument's value; the other is carried in
``flags.steps_per_minute_sum`` so a reader can see the divergence without the served
number having been invented from both. That is the same rule ``derive/vo2max_tier.py``
enforces for its three instruments, for the same reason: a number assembled from two
instruments has no validation behind it.

## Why this is a derivation now, and what that buys

Because the precedence lives in the DAY PASS, a repair is idempotent by construction:
re-deriving a day re-reads the raw counter and writes the same answer, however many times
it runs. The old shape could only ever be correct once, and only if the override was
remembered *after* every derivation forever — ``db/rederive`` did not remember it, so the
documented repair procedure actively replaced the authoritative count with the worse one.

The device's ``calories`` are stored raw and deliberately derive nothing: free-living
energy is the MET-by-state model in ``derive/energy.py`` (CLAUDE.md — never a device's own
HR-based number). [[distance_from_steps]], [[steps_mortality]].
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from uuid import UUID

from healthee.derive._common import Cur

# The per-minute sum's name on the wire, when it is the instrument that spoke. The
# DEVICE's name is not a constant here — it is read off the row it came from
# (``device_daily_total.source``, 'strap_0x16' today), so the served flag names the
# instrument that actually reported rather than one this module assumes.
SOURCE_PER_MINUTE = "steps_per_minute"


@dataclass(frozen=True)
class DeviceDailyTotal:
    """One stored ``device_daily_total`` row: what the strap itself reported for a day.

    Every measurement is optional because the payload's is: a report may carry steps
    without distance, and each field is read on its own.
    """

    day: date
    steps: int | None
    distance_m: float | None
    calories: float | None
    source: str
    reported_at: datetime


@dataclass(frozen=True)
class DailyValue:
    """One derived daily cell: the value, and the flags naming where it came from."""

    value: float
    flags: dict


def device_total(cur: Cur, user_id: UUID, day: date) -> DeviceDailyTotal | None:
    """The strap's own report for ``day``, or None when it never sent one."""
    cur.execute(
        "SELECT day, steps, distance_m, calories, source, reported_at "
        "FROM device_daily_total WHERE user_id = %s AND day = %s",
        (user_id, day),
    )
    row = cur.fetchone()
    if row is None:
        return None
    return DeviceDailyTotal(
        day=row[0],
        steps=None if row[1] is None else int(row[1]),
        distance_m=None if row[2] is None else float(row[2]),
        calories=None if row[3] is None else float(row[3]),
        source=str(row[4]),
        reported_at=row[5],
    )


def select_steps(device: DeviceDailyTotal | None, per_minute_sum: float) -> DailyValue:
    """The day's step count: the device's counter when it reported one, else the sum.

    Pure and total, so the precedence can be tested without a database. Both numbers
    reach the row — the served one as the value, the other as
    ``flags.steps_per_minute_sum`` — but only one of them IS the value. ``reported_at``
    rides along because a counter read at 09:00 is a statement about a partial day, and a
    reader comparing it against the per-minute sum needs to know that before concluding
    the stream stalled.
    """
    if device is None or device.steps is None:
        return DailyValue(per_minute_sum, {"source": SOURCE_PER_MINUTE})
    return DailyValue(
        float(device.steps),
        {
            "source": device.source,
            "steps_per_minute_sum": round(per_minute_sum),
            "reported_at": device.reported_at.isoformat(),
        },
    )


def select_distance(
    device: DeviceDailyTotal | None, steps: DailyValue, stride_m: float | None
) -> DailyValue | None:
    """The day's distance: the device's metres, else steps × stride. None when neither.

    Same shape as :func:`select_steps` one layer down, and the stride tier follows
    whichever step count won — a distance recomputed from the per-minute sum while
    ``steps_total`` carries the device counter would be two different days' worth of
    walking on one screen.

    ``stride_m is None`` means no profile (no height), which is the only reason the
    stride tier can be unavailable. A device-reported distance still lands then: it is a
    measurement and needs no anthropometry. [[distance_from_steps]].
    """
    if device is not None and device.distance_m is not None:
        return DailyValue(device.distance_m, {"source": device.source, "method": "device"})
    if stride_m is None:
        return None
    return DailyValue(
        steps.value * stride_m,
        {"source": steps.flags["source"], "method": "stride", "stride_m": round(stride_m, 3)},
    )
