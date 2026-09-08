"""Recovery + data-trust payloads for the Today page.

``recovery_score_payload`` (0-100 morning recovery + live readiness decay) and
``recovery_signals`` (individual favourable/unfavourable markers, no composite). Both
v2-native: ``derived_daily`` / ``sample`` / ``sleep_session``.

``data_health_payload`` lived here until the as-of-day work pushed this file past the
400-line gate a third time; it moved to ``read/data_health.py``, which was the right
home anyway — it is the one block of the Today page that describes NOW rather than a
calendar day, and that module's docstring is where the difference is argued.

``routine_today`` lived here until the illness override pushed this file past the
400-line gate; it moved to ``read/routine.py``, which was the right home anyway —
logging what the owner DID today is not a recovery concern (standards §1: a file has
one reason to change).

``recovery_signals`` and its three markers moved to ``read/recovery_signals.py`` when
naming their cut-points and disclosing which limb decides the sleep verdict pushed this
file past the gate again. Same reason as the three moves above: a marker-versus-personal-
history comparison and an evidence-weighted composite change for different reasons, and
every constant those signals use belongs to them alone.

The readiness-decay formula is ported VERBATIM (audit-verified). The recovery
"guidance" string — DETERMINISTIC rule-based text, never an LLM field — moved to
``read/recovery_guidance.py`` when a second caller needed the band vocabulary and this
file was at the 400-line gate again.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.core.logging import get_logger
from healthee.core.tenancy import reference_day, user_today
from healthee.derive._common import Cur
from healthee.derive.freshness import NOT_DERIVED_YET, unavailable_reason, withheld_block
from healthee.derive.robust import median
from healthee.read.common import TodayReads, latest_derived
from healthee.read.health_metrics import active_illness_severity
from healthee.read.recovery_guidance import daily_guidance, recovery_band

log = get_logger(__name__)


def recovery_score_payload(
    cur: Cur, user_id: UUID, tz: str, reads: TodayReads | None = None, day: date | None = None
) -> dict | None:
    """Morning recovery (0-100) + readiness decayed by the reference day's own strain.
    Always returns the per-factor breakdown so no bare number is shown.
    research/recovery/recovery_readiness.md."""
    as_of = reference_day(day, tz)
    latest = (
        reads.latest.get("recovery_score")
        if reads
        else latest_derived(cur, user_id, "recovery_score", as_of)
    )
    if not latest:
        return None
    score_day, score, flags = latest
    recovery = round(score)
    readiness, strain_today, typical = _live_readiness(cur, user_id, as_of, score_day, recovery)
    band = recovery_band(recovery)
    illness = active_illness_severity(cur, user_id, tz, as_of)
    return {
        "recovery": recovery,
        "readiness": readiness,
        "guidance": daily_guidance(band, readiness, recovery, flags.get("factors", {}), illness),
        "date": score_day.isoformat(),
        "band": band,
        "factors": flags.get("factors", {}),
        "weights": flags.get("weights", {}),
        "strain_today": round(strain_today, 1) if strain_today is not None else None,
        "typical_strain": round(typical, 1) if typical is not None else None,
        "note_id": "recovery_readiness",
    }


# ── Is that score TODAY's? — one answer for both LLM surfaces ────────────────
#
# ``recovery_score_payload`` has always carried ``date``. Both prompt builders DROPPED it
# and relabelled the value: ``insights/coach_context._recovery_block`` wrote "## Today's
# recovery … let it set intensity advice" and ``jobs/recs_context._recovery_line`` wrote
# "SETS today's intensity ceiling". So an unsynced strap fed a days-old score to the model
# as today's readiness, and it drove the intensity prescription — the worst version of this
# defect, because the number never reaches a UI where a date could rescue it.
#
# The fix is not to hide the score. A stale recovery is still the most recent evidence we
# have, and DELETING it would remove the conservative ceiling ("never prescribe a hard
# session on low recovery") that [[recovery_readiness]] exists to impose — trading a
# mislabelled number for an unconstrained model is a worse trade. So the value is kept,
# dated, and the dependent claim ("today's", "sets the ceiling") is dropped.
RECOVERY_MESSAGES = {
    NOT_DERIVED_YET: "There is no recovery score for today yet — sync the strap.",
}

# The instruction that must accompany a stale score, in ONE place so the coach prompt and
# the recs prompt cannot drift apart on it (they are separate LLM surfaces enforcing the
# same rule — ARCHITECTURE.md's "a new rule must be added in both places").
STALE_RECOVERY_DIRECTIVE = (
    "This is NOT today's recovery and must not be presented as today's readiness. Today's "
    "has not been computed. Without a current score there is no intensity ceiling to "
    "quote: say so plainly and advise on the conservative side."
)


def recovery_freshness(payload: dict, tz: str) -> dict | None:
    """``None`` when the score IS the owner's today, else why it isn't and how old it is.

    The FACT is shared; the wording is not. Each prompt builder renders this in its own
    voice but neither gets to decide whether the score is current — that question has one
    answer (``derive/freshness.py``).
    """
    today = user_today(tz)
    last_day = date.fromisoformat(payload["date"])
    reason = unavailable_reason(today, last_day)
    if reason is None:
        return None
    return withheld_block(reason, RECOVERY_MESSAGES[reason], today, last_day)


def _live_readiness(
    cur: Cur, user_id: UUID, as_of: date, day: date, recovery: int
) -> tuple[int, float | None, float | None]:
    """Only the REFERENCE DAY's own recovery decays (recovery is set at wake). Decay
    scales with that day's cardio-load vs the personal 30-day median, capped at -50%.
    Ported VERBATIM — conservative + transparent (no validated intraday formula).

    The comparison was against the wall clock and is now against the day being answered
    for, which is the same test on the current day and the only correct one on an older
    one: a score filed under 29 July decayed by that day's load is a fact about 29 July,
    whereas decaying it by today's would be two dates in one number.
    """
    if day != as_of:
        return recovery, None, None
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric='cardio_load' AND day=%s",
        (user_id, day),
    )
    cr = cur.fetchone()
    cur.execute(
        "SELECT value FROM derived_daily WHERE user_id = %s AND metric='cardio_load' "
        "AND day < %s AND day >= %s",
        (user_id, day, day - timedelta(days=30)),
    )
    hist = [float(r[0]) for r in cur.fetchall() if r[0] is not None]
    if not (cr and cr[0] is not None and len(hist) >= 5):
        return recovery, None, None
    strain_today = float(cr[0])
    typical = median(hist) or 1.0
    return decayed_readiness(recovery, strain_today, typical), strain_today, typical


def decayed_readiness(recovery: int, strain_today: float, typical: float) -> int:
    """Live readiness = recovery × (1 − decay); decay = 0.5·min(1, strain/typical),
    capped at −50%. Ported VERBATIM (conservative, no validated intraday formula)."""
    decay = 0.5 * min(1.0, strain_today / typical) if typical > 0 else 0.0
    return round(recovery * (1 - decay))
