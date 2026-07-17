"""Morning recovery / readiness score (0-100) for one local day.

Primary = overnight HRV (lnRMSSD) + resting HR vs the PERSONAL trailing baseline
(Plews/Buchheit); secondary = sleep-vs-NEED + respiratory rate. No peer-reviewed
formula combines these, so this is an honest evidence-weighted estimate ALWAYS
shown with its per-factor breakdown (the documented no-black-box exception). HRV/
RHR/RR are personal-relative; sleep is scored vs ABSOLUTE need. Ported verbatim
from legacy v2. Knowledge: [[recovery_readiness]].
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.derive._common import Cur, _clamp100, _upsert_daily

# Weights by evidence strength (not fitted) — recovery_readiness.
RECOVERY_WEIGHTS = {"hrv": 0.42, "rhr": 0.28, "sleep": 0.20, "rr": 0.10}
_BASELINE_DAYS = 42  # trailing window for the personal baseline
_BASELINE_MIN_POINTS = 5  # need at least this many days to trust a baseline
_MAD_TO_SD = 1.4826  # MAD -> robust SD (normal consistency constant)
_MIN_SD = 0.5  # floor on the robust SD so a flat history can't explode the z-score
_DEFAULT_NEED_MIN = 480.0  # sleep-need fallback


def _recovery_baseline(
    cur: Cur, user_id: UUID, metric: str, day: date, days: int = _BASELINE_DAYS
) -> tuple[float | None, float | None]:
    """Robust personal baseline (median + MAD*1.4826) over the trailing window.

    Excludes the day itself. (None, None) when fewer than 5 points are available.
    """
    cur.execute(
        "SELECT value FROM derived_daily "
        "WHERE user_id = %s AND metric=%s AND day < %s AND day >= %s",
        (user_id, metric, day, day - timedelta(days=days)),
    )
    vals = sorted(float(r[0]) for r in cur.fetchall())
    if len(vals) < _BASELINE_MIN_POINTS:
        return None, None
    n = len(vals)
    med = vals[n // 2] if n % 2 else 0.5 * (vals[n // 2 - 1] + vals[n // 2])
    devs = sorted(abs(v - med) for v in vals)
    mad = devs[len(devs) // 2]
    return med, max(mad * _MAD_TO_SD, _MIN_SD)


def _personal_factor(  # noqa: PLR0913 — one factor needs all its scoring inputs
    cur: Cur,
    user_id: UUID,
    day: date,
    factors: dict,
    key: str,
    metric: str,
    k: float,
    higher_better: bool,
) -> None:
    """Score one personal-baseline factor (50 + k*z, direction by `higher_better`)."""
    med, sd = _recovery_baseline(cur, user_id, metric, day)
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric=%s AND day=%s",
        (user_id, metric, day),
    )
    r = cur.fetchone()
    if not r or r[0] is None or med is None or sd is None:
        return
    v = float(r[0])
    z = (v - med) / sd
    sub = _clamp100(50 + k * z) if higher_better else _clamp100(50 - k * z)
    factors[key] = {
        "sub": round(sub),
        "z": round(z, 2),
        "value": round(v, 1),
        "baseline": round(med, 1),
    }


def _sleep_factor(cur: Cur, user_id: UUID, day: date, factors: dict) -> None:
    """Score sleep vs ABSOLUTE need (not the personal baseline)."""
    cur.execute(
        "SELECT (flags->>'tst_min')::float FROM derived_daily "
        "WHERE user_id = %s AND metric='sleep_health_score_4dim' AND day=%s",
        (user_id, day),
    )
    sr = cur.fetchone()
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric='sleep_need_min' "
        "AND day<=%s ORDER BY day DESC LIMIT 1",
        (user_id, day),
    )
    nr = cur.fetchone()
    need = float(nr[0]) if nr and nr[0] else _DEFAULT_NEED_MIN
    if sr and sr[0] is not None:
        tst = float(sr[0])
        factors["sleep"] = {
            "sub": round(_clamp100(100.0 * tst / need)),
            "tst_min": round(tst),
            "need_min": round(need),
        }


def derive_recovery(cur: Cur, user_id: UUID, day: date) -> dict | None:
    """0-100 morning recovery from overnight autonomic + sleep markers.

    Each factor is scored vs its baseline and combined by evidence-weighted
    contribution; the full per-factor breakdown rides in `flags` so the UI/LLM
    never show a bare number. None without at least one autonomic marker (HRV or
    RHR). [[recovery_readiness]].
    """
    factors: dict = {}
    _personal_factor(cur, user_id, day, factors, "hrv", "hrv_sleep_avg", 20.0, higher_better=True)
    _personal_factor(cur, user_id, day, factors, "rhr", "rhr_daily", 20.0, higher_better=False)
    _personal_factor(
        cur, user_id, day, factors, "rr", "respiratory_rate_sleep", 15.0, higher_better=False
    )
    _sleep_factor(cur, user_id, day, factors)

    if "hrv" not in factors and "rhr" not in factors:
        return None
    tw = sum(RECOVERY_WEIGHTS[k] for k in factors)
    score = sum(RECOVERY_WEIGHTS[k] * factors[k]["sub"] for k in factors) / tw
    flags = {
        "factors": factors,
        "weights": {k: RECOVERY_WEIGHTS[k] for k in factors},
        "method": "evidence_weighted_personal_baseline",
        "note_id": "recovery_readiness",
    }
    _upsert_daily(cur, user_id, day, "recovery_score", round(score), flags)
    return {"recovery_score": round(score)}
