"""When a recorded GPS track gets SCORED — the routine seam, and the gate (#111).

``derive.gps.derive_vo2max_submax`` knows how to read one session's VO2max. Until #111
the only thing that ever called it was the upload endpoint, once, at the instant the
track arrived — which is the worst possible moment to ask. The phone uploads the track
when the workout ends, while the strap's heart rate for the same window is still on the
strap, unsynced. The estimator correctly answers "no HR for this window (was the strap
worn?)", nothing retries, and the session is never scored again.

Measured in production on 2026-08-02: **8 GPS tracks, zero ``vo2max_submax`` rows**, for
weeks. Nothing failed — the upload returned 200 with an honest refusal inside it, and no
surface existed to notice that the refusal was permanent.

## The seam, and why it is this one (#107's shape, #107's fix)

This is a derivation reachable from ONE seam that nothing routine calls — the same
defect class as #107, so it takes the same structural fix rather than a second caller.
The scoring becomes part of :func:`derive.orchestrator.derive_day`, which means every
routine path already reaches it: a push that touches the day scores that day's tracks
(``ingest.service`` -> ``derive.derive_batch`` -> ``derive_day``), and so does the repair
tool (``db.rederive``, through the same ``derive_batch``). Nothing had to be added to
either caller, and neither can be given a track-scoring opinion of its own.

The upload path still scores immediately — the endpoint returns the estimate in its
response, and a track recorded after the strap already synced deserves its number now —
but it no longer *owns* the scoring: it calls the same :func:`score_track` the day pass
calls.

The nightly chain (``jobs/chain.py``) is deliberately NOT the seam. It derives nothing
today; it runs illness -> challenges -> correlate -> recs -> warm -> briefing over a
derived layer the push already built. Putting a derivation there would mean a second
entry point that can disagree with the first about order and freshness — the exact
property #107 collapsed into one function.

## The gate: ``gps_track.vo2max_submax IS NULL``

A track is scored at most once, and the marker is the denormalised estimate already
carried on the track row for the cheap list endpoint. :func:`_denormalise_summary` moved
here from ``read/gps.py`` together with the scoring, so the gate and the write that
closes it live in one place and cannot drift apart.

A track with no estimate is RE-ATTEMPTED whenever its day is derived, and that is the
design rather than a leak: the common failure is "the HR has not arrived yet", which a
later push fixes. It is bounded by the days a push actually touches, so a session that
genuinely cannot be scored (a flat walk — [[hr_reserve_vo2max]] refuses it, and should)
is retried only while its day is still receiving data, then never again. "No estimate
yet" and "no estimate possible" are not distinguishable from outside the estimator, and
guessing which one a refusal meant is how the original bug would come back.

The gate is deliberately NOT "does a ``derived_daily`` row cite this track". One day
holds exactly ONE ``vo2max_submax`` row (the metric's key is owner+day+metric), so with
two tracks in a day that test would mark whichever track lost the day's row as unscored
again — and the two would overwrite each other on every derive, forever.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.derive._common import Cur, _day_bounds_utc
from healthee.derive.gps import derive_vo2max_submax
from healthee.derive.gps_detail import gps_track_detail


def score_track(cur: Cur, user_id: UUID, tz: str, track_id: str) -> dict:
    """Score ONE track and denormalise its summary onto the track row.

    The one way a track gets scored: the upload endpoint and the day pass both call it,
    so the estimate and the ``gps_track`` summary that gates the next attempt can never
    be written by one path and skipped by the other. Runs in the CALLER's transaction and
    commits nothing. Returns whatever the estimator returned, refusal included.
    """
    vo2 = derive_vo2max_submax(cur, user_id, tz, track_id)
    _denormalise_summary(cur, user_id, track_id, vo2)
    return vo2


def unscored_tracks(cur: Cur, user_id: UUID, tz: str, day: date) -> list[str]:
    """The owner's tracks STARTING inside local ``day`` that carry no estimate, oldest first.

    Bounded by the day's UTC instants (``_day_bounds_utc``) rather than an
    ``AT TIME ZONE`` cast, so the ``(user_id, start_ts)`` index is usable. Keyed on the
    START because that is the instant :func:`derive_vo2max_submax` turns into the day it
    files the row under — a track selected for a day therefore writes to that same day,
    by construction rather than by coincidence.
    """
    start_utc, end_utc = _day_bounds_utc(day, tz)
    cur.execute(
        "SELECT id FROM gps_track WHERE user_id = %s AND start_ts >= %s AND start_ts < %s "
        "AND vo2max_submax IS NULL ORDER BY start_ts",
        (user_id, start_utc, end_utc),
    )
    return [str(row[0]) for row in cur.fetchall()]


def score_day_tracks(cur: Cur, user_id: UUID, tz: str, day: date) -> dict:
    """Score every not-yet-scored track of ``day`` — the seam ``derive_day`` calls.

    Oldest first, and which session ends up owning the day's single ``vo2max_submax`` cell
    is decided by ``derive/gps._store``, on the tier's own precedence rather than on
    arrival order. This docstring used to say the LATEST session owns it and treated that
    as harmless; write-path audit B1 is that it is not, because ``vo2max_tier`` reads the
    measured tier out of those cells and nothing else, so a graded fit at 09:00 lost the
    day to a reserve inversion at 18:00. Returns ``{}`` when nothing was pending, so a day
    without GPS adds nothing to the derive result and costs one indexed lookup.

    ``vo2max_submax`` in the returned dict is the LAST scored session's own estimate, which
    is a report of what this pass did — not a claim about which value the day now carries.
    """
    pending = unscored_tracks(cur, user_id, tz, day)
    if not pending:
        return {}
    out: dict = {"gps_tracks_scored": 0}
    for track_id in pending:
        result = score_track(cur, user_id, tz, track_id)
        if result.get("ok"):
            out["gps_tracks_scored"] += 1
            out["vo2max_submax"] = result["vo2max_submax"]
    return out


def forget_track_estimates(cur: Cur, user_id: UUID, tz: str, days: list[date]) -> int:
    """Clear the stored estimates across ``days`` so the day pass scores those tracks again.

    The escape hatch for a SCIENCE change that moves values already computed
    (``db.rederive --rescore-tracks``). Without it the gate is permanent and a change to
    the estimator would silently leave every scored session on its old number. It
    RE-OPENS the gate rather than bypassing it, so there is still exactly one rule about
    when a track gets scored — and the re-score therefore runs through the same
    :func:`score_track` as everything else. ``days`` is the caller's window, oldest first.
    """
    start_utc, _ = _day_bounds_utc(days[0], tz)
    _, end_utc = _day_bounds_utc(days[-1], tz)
    cur.execute(
        "UPDATE gps_track SET vo2max_submax = NULL, r2 = NULL "
        "WHERE user_id = %s AND start_ts >= %s AND start_ts < %s",
        (user_id, start_utc, end_utc),
    )
    return cur.rowcount


def _denormalise_summary(cur: Cur, user_id: UUID, track_id: str, vo2: dict) -> None:
    """Write distance/duration/HR/elevation + the submax estimate onto the track row.

    Feeds the cheap list endpoint, and ``vo2max_submax`` here doubles as the scoring gate
    (module docstring) — which is why this moved out of ``read/gps.py`` with the scoring
    rather than staying beside the endpoint that used to be its only caller.
    """
    det = gps_track_detail(cur, user_id, track_id)
    if not det:
        return
    s = det["summary"]
    cur.execute(
        "UPDATE gps_track SET distance_m=%s, duration_s=%s, avg_hr=%s, ele_gain_m=%s, "
        "vo2max_submax=%s, r2=%s WHERE user_id=%s AND id=%s",
        (
            round(s["distance_km"] * 1000),
            s["duration_s"],
            s["avg_hr"],
            s["ele_gain_m"],
            (vo2.get("vo2max_submax") if vo2.get("ok") else None),
            (vo2.get("r2") if vo2.get("ok") else None),
            user_id,
            track_id,
        ),
    )
