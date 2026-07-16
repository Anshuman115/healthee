"""Personal caffeine + alcohol cutoff-time finder — v2-native.

For each substance, Mann-Whitney U on sleep outcomes between nights with a
substance event after hour H vs before-H/none, iterating H ∈ {12,14,16,18,20,22}
in the OWNER's local time. The earliest H producing a significant effect **in the
literature-expected direction** is the personal cutoff. Evidence:
[[caffeine_sleep]] (Drake 2013, Clark & Landolt 2017), [[alcohol_sleep]]
(Ebrahim 2013, Pietilä 2018).

★ THE SEAM FIX (this finder was silently dead on v2): legacy read total sleep
time from ``session.summary->>'tst_minutes'``, which is always NULL on v2, so
every night was discarded and the finder returned nothing. v2 reads TST directly
from ``sleep_session`` (``rem_min + light_min + deep_min``) and the per-night HRV
/ RHR outcomes from ``derived_daily`` — so the finder actually fires. The stats
(MWU, rank-biserial, family-wise BH-FDR, direction gate) are ported verbatim.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.analytics.finding import EFFECT_MANN_WHITNEY, Finding, replace_findings_of_kind
from healthee.analytics.series import Cur
from healthee.analytics.stats import bh_fdr, mann_whitney_groups
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID

# Candidate cutoffs, as hours-of-day in the owner's local timezone.
CUTOFF_HOURS: tuple[int, ...] = (12, 14, 16, 18, 20, 22)

# Power thresholds (a touch permissive — a pre-registered hypothesis test, not a
# fishing expedition, so a lower FDR penalty). Verbatim from legacy.
MIN_INTAKE_NIGHTS = 10
MIN_AFTER_H_NIGHTS = 5
MIN_CONTROL_NIGHTS = 10
P_THRESHOLD = 0.10
MIN_RANK_BISERIAL = 0.30
FDR_Q_THRESHOLD = 0.20

# Outcomes + literature-expected direction (-1 lower / +1 higher in the after-H
# group). Keys match the night dict from ``_load_sleep_nights`` — note the v2
# rename ``hrv_sleep_avg_ms`` → ``hrv_sleep_avg``.
CAFFEINE_EXPECTED: dict[str, int] = {
    "tst_min": -1,  # Drake 2013: ~1 h shorter
    "efficiency_pct": -1,  # Drake 2013: more wake
    "hrv_sleep_avg": -1,  # autonomic stimulation
    "rhr_daily": +1,
}
ALCOHOL_EXPECTED: dict[str, int] = {
    "hrv_sleep_avg": -1,  # Ebrahim 2013, Pietilä 2018 (strongest)
    "rhr_daily": +1,  # Ebrahim 2013
    "efficiency_pct": -1,
    "tst_min": -1,
}
SUBSTANCE_CONFIG: dict[str, dict] = {
    "caffeine": {"expected": CAFFEINE_EXPECTED, "note_ids": ["caffeine_sleep"]},
    "alcohol": {"expected": ALCOHOL_EXPECTED, "note_ids": ["alcohol_sleep"]},
}

_SECONDS_PER_DAY = 24 * 3600


def _load_sleep_nights(cur: Cur, user_id: UUID, tz: str) -> list[dict]:
    """One row per main-sleep night with the outcomes the finder tests.

    TST from ``sleep_session`` stage minutes (the seam fix); efficiency from
    TST/TIB; HRV and RHR joined per wake-date from ``derived_daily``.
    """
    cur.execute(
        """
        SELECT start_ts,
               (end_ts AT TIME ZONE %s)::date AS wake_date,
               (rem_min + light_min + deep_min)::float AS tst_min,
               EXTRACT(EPOCH FROM (end_ts - start_ts)) / 60.0 AS tib_min
        FROM sleep_session
        WHERE user_id = %s AND kind = 'main'
        ORDER BY start_ts
        """,
        (tz, user_id),
    )
    # Materialise the session rows BEFORE issuing more queries on this cursor —
    # _daily_map re-executes it, which would otherwise discard this result set.
    session_rows = cur.fetchall()
    hrv = _daily_map(cur, user_id, "hrv_sleep_avg")
    rhr = _daily_map(cur, user_id, "rhr_daily")
    nights: list[dict] = []
    for start_ts, wake_date, tst_min, tib_min in session_rows:
        if tst_min is None or tib_min is None or tib_min <= 0:
            continue
        tst, tib = float(tst_min), float(tib_min)
        nights.append(
            {
                "start_ts": start_ts,
                "wake_date": wake_date,
                "tst_min": tst,
                "efficiency_pct": 100.0 * tst / tib if tib > 0 else None,
                "hrv_sleep_avg": hrv.get(wake_date),
                "rhr_daily": rhr.get(wake_date),
            }
        )
    return nights


def _daily_map(cur: Cur, user_id: UUID, metric: str) -> dict[date, float]:
    """day → value for a ``derived_daily`` metric (for the per-night join)."""
    cur.execute(
        "SELECT day, value FROM derived_daily WHERE user_id = %s AND metric = %s",
        (user_id, metric),
    )
    return {r[0]: float(r[1]) for r in cur.fetchall()}


def _load_substance_events(cur: Cur, user_id: UUID, tz: str, kind: str) -> list[dict]:
    """All ``manual_entry`` rows for the substance with local hour-of-day."""
    cur.execute(
        """
        SELECT ts,
               EXTRACT(HOUR   FROM (ts AT TIME ZONE %s))::int AS h,
               EXTRACT(MINUTE FROM (ts AT TIME ZONE %s))::int AS mn
        FROM manual_entry WHERE user_id = %s AND kind = %s ORDER BY ts
        """,
        (tz, tz, user_id, kind),
    )
    return [{"ts": r[0], "hour_local": r[1] + r[2] / 60.0} for r in cur.fetchall()]


def _classify_nights(
    nights: list[dict], events: list[dict], cutoff_h: int
) -> tuple[list[dict], list[dict]]:
    """Split nights into (after_H, before_or_none) groups (verbatim).

    "after_H": a substance event occurred in the 24 h before sleep onset with
    local hour-of-day ≥ cutoff_h.
    """
    after_h: list[dict] = []
    control: list[dict] = []
    for n in nights:
        max_hour: float | None = None
        for ev in events:
            delta_s = (n["start_ts"] - ev["ts"]).total_seconds()
            in_window = 0 <= delta_s <= _SECONDS_PER_DAY
            if in_window and (max_hour is None or ev["hour_local"] > max_hour):
                max_hour = ev["hour_local"]
        is_after = max_hour is not None and max_hour >= cutoff_h
        (after_h if is_after else control).append(n)
    return after_h, control


def _values(group: list[dict], outcome: str) -> list[float]:
    return [n[outcome] for n in group if n.get(outcome) is not None]


def compute_cutoff_findings(user_id: UUID, tz: str) -> list[Finding]:
    """Detect personal cutoffs for caffeine + alcohol; FDR within the family."""
    with tenant_transaction(user_id) as cur:
        nights = _load_sleep_nights(cur, user_id, tz)
        if len(nights) < MIN_CONTROL_NIGHTS:
            return []
        substance_events = {
            s: _load_substance_events(cur, user_id, tz, s) for s in SUBSTANCE_CONFIG
        }

    candidates: list[Finding] = []
    for substance, cfg in SUBSTANCE_CONFIG.items():
        events = substance_events[substance]
        if len({ev["ts"].date() for ev in events}) < MIN_INTAKE_NIGHTS:
            continue
        for outcome, expected_dir in cfg["expected"].items():
            found = _first_significant_cutoff(
                nights, events, tz, substance, outcome, expected_dir, cfg
            )
            if found is not None:
                candidates.append(found)

    for f, q in zip(candidates, bh_fdr([f.p_value for f in candidates]), strict=True):
        f.q_value = q
        f.significant = q <= FDR_Q_THRESHOLD and abs(f.effect_size) >= MIN_RANK_BISERIAL
    return candidates


def _first_significant_cutoff(  # noqa: PLR0913 — the cutoff search needs each input
    nights: list[dict],
    events: list[dict],
    tz: str,
    substance: str,
    outcome: str,
    expected_dir: int,
    cfg: dict,
) -> Finding | None:
    """Earliest cutoff hour with a directionally-correct significant effect."""
    for h in CUTOFF_HOURS:
        after_h, control = _classify_nights(nights, events, h)
        res = mann_whitney_groups(
            _values(after_h, outcome),
            _values(control, outcome),
            MIN_AFTER_H_NIGHTS,
            MIN_CONTROL_NIGHTS,
        )
        if not res:
            continue
        rb, p, n_a, n_c, med_a, med_c = res
        if (expected_dir < 0 and rb >= 0) or (expected_dir > 0 and rb <= 0):
            continue  # wrong direction — uninformative for this hypothesis
        if abs(rb) < MIN_RANK_BISERIAL or p >= P_THRESHOLD:
            continue
        return _cutoff_finding(
            substance, outcome, tz, h, rb, p, n_a, n_c, med_a, med_c, expected_dir, cfg
        )
    return None


def _cutoff_finding(  # noqa: PLR0913 — one finding needs all its measured fields
    substance: str,
    outcome: str,
    tz: str,
    h: int,
    rb: float,
    p: float,
    n_a: int,
    n_c: int,
    med_a: float,
    med_c: float,
    expected_dir: int,
    cfg: dict,
) -> Finding:
    return Finding(
        kind="personal_cutoff",
        # `h` is an hour-of-day in the OWNER's zone (`_load_substance_events` bucketed
        # it with `AT TIME ZONE tz`), so the description must name THAT zone — the
        # hardcoded "IST" was true only for the sentinel owner. The IANA name is used
        # verbatim rather than an abbreviation: `%Z` would render an ambiguous label
        # ("IST" is India, Ireland AND Israel) that also shifts with DST, so it could
        # disagree with the hours actually analysed. A finding description must not
        # lie about which clock it refers to.
        description=(
            f"{substance.capitalize()} after {h:02d}:00 {tz} → {outcome} median "
            f"{med_a:.1f} vs {med_c:.1f} (n_after={n_a}, n_other={n_c}, p={p:.3f})."
        ),
        metric_a=f"{substance}_after_{h:02d}",
        metric_b=outcome,
        event_kind=substance,
        lag_days=0,
        effect_size=rb,
        effect_metric=EFFECT_MANN_WHITNEY,
        p_value=p,
        q_value=None,
        n_samples=n_a + n_c,
        significant=False,
        research_note_ids=list(cfg["note_ids"]),
        details={
            "substance": substance,
            "cutoff_hour": h,
            "cutoff_tz": tz,
            "outcome": outcome,
            "n_after": n_a,
            "n_other": n_c,
            "median_after": med_a,
            "median_other": med_c,
            "expected_dir": expected_dir,
        },
    )


def persist_cutoff_findings(findings: list[Finding]) -> int:
    """Replace all ``personal_cutoff`` findings with the fresh set (stale removal)."""
    return replace_findings_of_kind(SENTINEL_USER_ID, "personal_cutoff", findings)
