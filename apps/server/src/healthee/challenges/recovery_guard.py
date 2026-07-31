"""ONE definition of "do not push this owner harder right now".

[[recovery_readiness]] D7 — safety inputs are hard overrides, not votes — and D8 —
recovery *eases or holds*, it never escalates. There are exactly two places in this
package where the engine can escalate a training load, and until now only one of them
asked:

* **generation** (``levers``) refuses to OFFER a hard training lever while the owner's
  trailing-week recovery sits in the ``low`` band or an illness flag is active
  (CHALLENGES.md §5.1b, WP-C3c);
* **adaptation** (``adapt``) may RAISE a target on a challenge already adopted — and it
  raised on performance alone, so the owner beating their MVPA target *because* they
  were overtraining got ratcheted further in. The safety rule existed; the adapter
  simply did not consult it.

That asymmetry was built by accident, and the fix that would build it again is a second
copy of the rule in ``adapt``. So the rule lives here and both callers read it. The
frame is each caller's (a menu withholds a lever, the adapter withholds a raise); the
**decision** — which metrics, and on what owner state — is this module's alone.

Nothing here decides what to DO about the hold. It reports the reason and its callers
refuse in their own vocabulary, the same shape ``screen`` uses for a rejected proposal
and ``ledger`` uses for ``data_confidence``: a refusal that says which rule produced it
is a useful answer, and a silent one is not (standards §Errors).
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.analytics.series import daily_series
from healthee.challenges.series import MIN_COMPARISON_DAYS
from healthee.derive._common import Cur
from healthee.derive.robust import median
from healthee.read.health_metrics import active_illness_severity
from healthee.read.recovery import recovery_band

# The metrics whose target IS a training stimulus. Raising one of these, or offering it
# in the first place, asserts "you can absorb more load" — which is exactly the claim an
# under-recovered owner's own data contradicts.
#
# `steps_total` and `active_calories` are deliberately NOT here: legacy's own
# recovery-aware prescription favoured Zone-2 work and daily steps precisely as the
# ALTERNATIVE to intensity, and [[recovery_readiness]] eases intensity rather than
# movement. `tst_min` and `sri` are not here because they are recovery-SUPPORTING —
# withholding a sleep or regularity target from someone sleeping badly would withhold
# the one thing that helps. The two cap metrics are not here because a `<=` rule cannot
# be "raised" at all (`adapt.suggest_adaptation` leaves every cap alone) and a cap is a
# reduction in exposure, not an increase in load.
HARD_TRAINING_LEVERS: frozenset[str] = frozenset({"mvpa_min", "cardio_load", "workouts_week"})

# How far back the recovery read looks. [[recovery_readiness]] D3: act on the multi-day
# trend, never one morning — a single low day is noise, and withholding somebody's
# training lever on noise is its own kind of dishonesty. The "enough days" line is
# `series.MIN_COMPARISON_DAYS`, the one this package already judges a window by.
RECOVERY_TREND_DAYS = 7


def recovery_state(cur: Cur, user_id: UUID, tz: str, today: date) -> tuple[str | None, str | None]:
    """The owner's trailing-week recovery band and any active illness flag.

    The band is taken over the MEDIAN of the trailing week rather than the latest morning
    ([[recovery_readiness]] D3), and it is ``None`` — unknown, not "fine" — below
    ``MIN_COMPARISON_DAYS`` of scores. Unknown does not withhold anything: "we cannot
    tell" is not "you are under-recovered", and refusing a lever on absent data would be
    the optimistic guess run backwards.
    """
    scores = daily_series(
        cur, user_id, "recovery_score", today - timedelta(days=RECOVERY_TREND_DAYS)
    )
    values = [v for day, v in scores.items() if day <= today]
    band = recovery_band(median(values)) if len(values) >= MIN_COMPARISON_DAYS else None
    return band, active_illness_severity(cur, user_id, tz, today)


def hold_reason(metric: str, recovery: str | None, illness: str | None) -> str | None:
    """Why ``metric`` may not be pushed harder for this owner right now, or ``None``.

    The CAUSE clause only, without a verdict attached, because the two callers refuse
    different things and a sentence that fits a menu ("withheld from your options")
    would be wrong on a live commitment ("not raised"). What must not be duplicated is
    the decision, and the decision is entirely here: the metric set, the band that
    counts as low, and illness overriding the band.
    """
    if metric not in HARD_TRAINING_LEVERS:
        return None
    if illness:
        return "an illness signal is active"
    if recovery == "low":
        return "recovery has been low all week"
    return None
