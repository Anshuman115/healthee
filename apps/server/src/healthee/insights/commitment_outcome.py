"""What happened after a commitment — the third source of the owner's own evidence.

Roadmap C2 asks for one personal-evidence store the coach reads. Two of its three
sources were already there and already unified in practice: correlations from the
`finding` table (`context_sessions.findings_section`) and the frozen challenge
ledger (`challenge_context.challenge_section`), both rendered into the coach's
context and both cited as `[personal_finding:…]`. The missing third is C1's
commitments: the owner agreed to change something, said whether they did, and
nothing ever looked at what the metric did afterwards.

## It reuses the challenge ledger's rules rather than inventing softer ones

Every number here comes from `challenges.series.recent_window` and every judgement
from `MIN_COMPARISON_DAYS` — the same estimator and the same line the outcome
ledger uses. That is deliberate and it is the point: a commitment before/after is
a weaker claim than a challenge's (no target, no adoption gate, self-reported), so
it must not be computed by a *more permissive* rule. Two definitions of "the
metric moved" is the failure CLAUDE.md names.

## ⛔ What this is NOT

**Not proof, and not attribution.** A kept commitment is one person changing one
thing they chose to change, with no control and no blinding. The delta is
CO-OCCURRING with the commitment and everything else in that window — a running
challenge, an illness, a holiday. `confounds` says which of those were present and
the coach is required to speak them.

**Not a verdict on the person.** `kept` is what they said, not what we measured;
this module reads the metric, never the adherence.

**Not published when thin.** Fewer than `MIN_COMPARISON_DAYS` measured days on
either side and there is no before/after — the outcome says `insufficient_data`
and carries no numbers, exactly as the challenge ledger does. A comparison from
two days is two anecdotes.

**Not published before the after-window clears the commitment.** The estimator
averages a trailing `BASELINE_DAYS`, so a commitment made three days ago has an
"after" side four of whose seven days are *before* it was made — days that are by
definition the baseline. It would still pass the measured-days gate, and it would
report a delta near zero for a change that had barely started. So an outcome does
not exist until `BASELINE_DAYS` have elapsed since the commitment. That is not a
missing feature to work around: a behaviour change is not measurable on its third
day, and saying so is the product.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from uuid import UUID

from healthee.challenges import confounds as confounds_mod
from healthee.challenges.series import BASELINE_DAYS, MIN_COMPARISON_DAYS, recent_window
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today

log = get_logger(__name__)

#: The cadence a commitment's metric is read at.
#:
#: `daily` — a commitment is about a behaviour repeated day to day ("move coffee
#: before 2"), so the honest reading is the per-day level either side of it. A
#: `weekly`/`total` cadence would be the challenge system's units, and a commitment
#: carries no window to sum over.
_CADENCE = "daily"

#: How the outcome describes its own trustworthiness. `challenge_outcome`'s words,
#: because a reader meeting both must not have to learn two vocabularies.
OK = "ok"
INSUFFICIENT = "insufficient_data"


@dataclass(frozen=True)
class CommitmentOutcome:
    """One commitment's before→after, or an honest refusal to state one."""

    commitment_id: int
    stated: str
    metric: str
    confidence: str
    before: float | None
    after: float | None
    before_days: int
    after_days: int
    confounds: dict

    @property
    def delta(self) -> float | None:
        """After minus before, or None when there is no comparison to make."""
        if self.before is None or self.after is None:
            return None
        return round(self.after - self.before, 1)


def outcome_for(
    user_id: UUID, tz: str, commitment_id: int, stated: str, metric: str, since: date
) -> CommitmentOutcome:
    """Read what `metric` did either side of `since` for one kept commitment.

    `since` is the day the commitment was made, not the day it was resolved: the
    change starts when they agreed to it, and a window anchored on the resolution
    would put most of the change in the "before" side.
    """
    today = user_today(tz)
    with tenant_transaction(user_id) as cur:
        before, before_days = recent_window(cur, user_id, tz, metric, _CADENCE, since)
        after, after_days = recent_window(cur, user_id, tz, metric, _CADENCE, today)
        found = confounds_mod.collect(
            cur,
            user_id,
            tz,
            {"id": None, "metric": metric, "cadence": _CADENCE},
            since,
            today,
        )
    # Two gates, and both are about the same thing — whether the "after" side is
    # actually after. `elapsed` is the calendar one: the estimator's window is a
    # trailing `BASELINE_DAYS`, so until that many days have passed the window still
    # reaches back over the commitment into its own baseline. `before_days`/
    # `after_days` are the measurement one: enough days in each window actually
    # recorded. A window can clear the first and fail the second, and vice versa.
    elapsed = (today - since).days
    thin = elapsed < BASELINE_DAYS or min(before_days, after_days) < MIN_COMPARISON_DAYS
    if thin:
        # Written, not withheld: "we cannot say" is an answer and the coach is
        # expected to give it. But it carries NO numbers — a value beside an
        # `insufficient_data` label is the number people read and the label they do
        # not, which is the whole reason the challenge ledger blanks them too.
        log.info(
            "commitment %s outcome is thin (%s days elapsed, %s/%s measured)",
            commitment_id,
            elapsed,
            before_days,
            after_days,
        )
        return CommitmentOutcome(
            commitment_id,
            stated,
            metric,
            INSUFFICIENT,
            None,
            None,
            before_days,
            after_days,
            found,
        )
    return CommitmentOutcome(
        commitment_id,
        stated,
        metric,
        OK,
        before,
        after,
        before_days,
        after_days,
        found,
    )
