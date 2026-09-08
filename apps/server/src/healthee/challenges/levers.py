"""WP-C3c — where THIS owner has the most to gain, decided before the model is asked.

CHALLENGES.md §5.1b. WP-C3 hands the model a calibration table and lets it pick a metric;
nothing pointed it at the metric where this person actually has room. COACH_PROMPT.md
already names the job — *"identify the single biggest lever for this person right now (the
gap between where they are and where the evidence says the returns are largest)"* — and
this module is that sentence made computable. The model still writes every word; it no
longer chooses the lever or the number.

## An ordering, not a score — and the argument for it

The obvious design is a 0–100 "opportunity score" blending gap, curve steepness, personal
effect size and recovery. CLAUDE.md forbids that outright (no composite scores without a
documented methodology and a research note), and here the ban is not a formality: the
inputs share no scale. A mortality-hazard gap in steps, a Spearman rho on sleep minutes
and a recovery band are three different kinds of quantity, and any weight placed between
them would be **invented and then rendered as a number** — the exact move
``recovery_readiness`` gets to make only because it publishes its weights, its per-factor
breakdown and a note that says the composite is unvalidated.

So this is a **lexicographic ordering over named rules**, each of which is either a
boolean or a directly-reported quantity. Nothing is summed, nothing is normalised, and
every lever carries its own gap, target and citation so the ordering can be read back:

0. a **personal finding** implicates the metric (their own measured evidence),
1. a **population gap** on a curve the corpus says is **steepest at the bottom**,
2. a population gap with no curve-shape evidence,
3. at or past the evidence target — no gap left,
4. **unranked**: no population target exists, so no gap is computable.

Ties inside a tier break on the shown gap fraction (|effect| for tier 0), then on
"haven't tried it yet". Tier 4 is an honest output rather than a hole — ``cardio_load``
and ``active_calories`` are individual-load quantities with no population dose-response,
so we say we cannot place them instead of inventing somewhere to place them.

## Exclusions are a separate axis, and they are enforced

A lever can be excluded without being un-ranked, and exclusion is checked in ``screen``
alongside the bounds check — instructed AND enforced, the whole theme of this track:

* **active** — never duplicate a live commitment.
* **recently abandoned** — they dropped it. Legacy's prompt told itself to route around
  abandons and never checked; a prompt rule nobody enforces is decoration.
* **a hard training lever while under-recovered** — [[recovery_readiness]] D7 (safety
  inputs are hard overrides, not votes) and D8 (recovery eases or holds, it never
  escalates). Legacy encoded this by hardcoding *"this user is a chronic short sleeper
  with low recovery"* into the prompt for its single tenant; it is computed per owner
  in ``recovery_guard``, which is also what stops ``adapt`` from RAISING a lever this
  module refuses to offer — the rule is one definition read by both.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import date, datetime, time, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from healthee.challenges import commitment, ledger
from healthee.challenges.bounds import Calibration
from healthee.challenges.lever_findings import finding_token, findings_by_metric
from healthee.challenges.metrics import CHALLENGE_METRICS, spec
from healthee.challenges.recovery_guard import hold_reason, recovery_state
from healthee.challenges.targets import STEEPEST_AT_LOW, U_SHAPED, curve_of, natural_cadence
from healthee.challenges.windowed import WindowedManualEntrySource, evidence_notes
from healthee.derive._common import Cur

# The tiers, in order. Named rather than numbered at the call sites so a reordering is a
# visible edit to this tuple and not a magic integer that drifted.
PERSONAL_FINDING = "personal_finding"
STEEP_GAP = "steep_gap"
GAP = "gap"
AT_TARGET = "at_target"
UNRANKED = "unranked"
BLOCKED = "blocked"
_TIER_ORDER = (PERSONAL_FINDING, STEEP_GAP, GAP, AT_TARGET)

# How long an abandoned metric stays off the menu. PROVISIONAL, like every constant in
# `targets`: the ledger records `status='abandoned'` with `ended_at`, so "how long before
# a re-offer is welcome rather than nagging" is answerable from outcomes later and is a
# guess now. Two months is long enough that the re-offer is not the same conversation.
ABANDON_COOLDOWN_DAYS = 60

# How many frozen outcomes the TIE-BREAK reads back. The same tail `gen_context` shows the
# model, one order of magnitude up.
#
# It is a tail on purpose and only `_attempted_metrics` may use it: "has this owner ever
# committed to this metric" is a heuristic that orders two otherwise equal offers, and a
# heuristic reading a tail is honest about being one. `_recently_abandoned` used to share
# it under the reason "these rules only care about the LATEST row per metric, and there
# are nine metrics" — which is not what made 50 sufficient. What made it sufficient was an
# unstated invariant (fewer than ~50 outcomes frozen in any 60 days) that the legal worst
# case exceeds, so a 60-day RULE was resting on a row count that cannot express it. That
# read is now bounded by the cooldown itself (`ledger.since`).
_HISTORY_ROWS = 50


@dataclass(frozen=True)
class Lever:
    """One metric's standing for one owner — its rank, and everything that produced it."""

    metric: str
    rank: int | None
    tier: str
    cadence: str  # the cadence the gap is denominated in ("daily" | "weekly")
    baseline: float | None
    target: float | None
    target_note: str | None
    gap: float | None
    gap_fraction: float | None
    curve: str
    curve_note: str | None
    finding: str | None
    finding_effect: float | None
    blocked: str | None


@dataclass(frozen=True)
class LeverAnalysis:
    """The ranked levers plus the owner state that excluded any of them."""

    levers: tuple[Lever, ...]
    recovery: str | None
    illness: str | None

    def blocked_metrics(self) -> dict[str, str]:
        """metric → why it may not be proposed. The map ``screen`` enforces."""
        return {lever.metric: lever.blocked for lever in self.levers if lever.blocked}

    def ranked(self) -> tuple[Lever, ...]:
        return tuple(lever for lever in self.levers if lever.rank is not None)


def analyse(
    cur: Cur,
    user_id: UUID,
    tz: str,
    today: date,
    calibrations: dict[tuple[str, str], Calibration],
    active_metrics: set[str],
) -> LeverAnalysis:
    """Rank every registry metric for one owner, and say which are off the menu.

    ``calibrations`` is passed in rather than recomputed so the baseline a gap is measured
    from is provably the same number Gate A will bound the proposal against — two reads
    could disagree if a day rolled over between them.
    """
    recovery, illness = recovery_state(cur, user_id, tz, today)
    findings = findings_by_metric(cur, user_id)
    abandoned = _recently_abandoned(cur, user_id, tz, today)
    attempted = _attempted_metrics(cur, user_id)
    levers = [
        _lever(
            metric,
            calibrations,
            finding=findings.get(metric),
            blocked=_blocked_reason(
                metric, active_metrics, abandoned, recovery, illness, findings.get(metric)
            ),
        )
        for metric in sorted(CHALLENGE_METRICS)
    ]
    return LeverAnalysis(tuple(_ranked(levers, attempted)), recovery, illness)


def _lever(
    metric: str,
    calibrations: dict[tuple[str, str], Calibration],
    *,
    finding: dict | None,
    blocked: str | None,
) -> Lever:
    """One metric's gap, in the cadence its target is denominated in."""
    curve = curve_of(metric)
    cadence = natural_cadence(metric)
    calibration = calibrations.get((metric, cadence))
    baseline = None if calibration is None else calibration.baseline
    target = None if calibration is None else calibration.target
    gap, fraction = _gap(metric, baseline, target, spec(metric).good)
    return Lever(
        metric=metric,
        rank=None,
        tier=_tier(finding, gap, curve.shape, blocked, _calibratable(metric, calibrations)),
        cadence=cadence,
        baseline=baseline,
        target=target,
        target_note=None if calibration is None else calibration.target_note,
        gap=gap,
        gap_fraction=fraction,
        curve=curve.shape,
        curve_note=curve.note_id,
        finding=None if finding is None else finding_token(finding),
        finding_effect=None if finding is None else abs(float(finding["effect_size"])),
        blocked=blocked,
    )


def _calibratable(metric: str, calibrations: dict[tuple[str, str], Calibration]) -> bool:
    """True when SOME cadence of ``metric`` has a band Gate A would accept a target in.

    A metric Gate A cannot calibrate is not a lever at any rank — there is no number we
    could honestly ask for. It is reported as UNRANKED rather than blocked, because the
    calibration table already tells the model it is unavailable AND says why (with the
    refusal that distinguishes "we have none of your data" from "your data says zero");
    saying it twice in two vocabularies is how a prompt starts contradicting itself.
    """
    return any(
        calibrations.get((metric, cadence)) is not None
        and calibrations[(metric, cadence)].band is not None
        for cadence in ("daily", "weekly")
    )


def _gap(
    metric: str, baseline: float | None, target: float | None, direction: str
) -> tuple[float | None, float | None]:
    """Distance to the population target, signed so positive always means "room to gain".

    A ``U_SHAPED`` metric only has a gap BELOW its target: overshooting the sleep band is
    a real risk, but the long tail is read as a marker of illness rather than something to
    chase, and the registry has no way to express "sleep less" anyway. So an owner above
    the band gets a gap of zero — no lever — rather than a negative one.
    """
    if baseline is None or target is None:
        return None, None
    room = target - baseline if direction == "up" else baseline - target
    if room < 0 and curve_of(metric).shape == U_SHAPED:
        room = 0.0
    return room, room / target if target else None


def _tier(
    finding: dict | None, gap: float | None, shape: str, blocked: str | None, calibratable: bool
) -> str:
    """Which named rule places this metric — the ordering's only decision.

    ``blocked`` wins over everything: a lever the owner may not be offered has no useful
    rank, and ranking it anyway would put a metric at the top of a list the model is
    forbidden to propose from.
    """
    if blocked is not None:
        return BLOCKED
    if not calibratable:
        return UNRANKED
    if finding is not None:
        return PERSONAL_FINDING
    if gap is None:
        return UNRANKED
    if gap <= 0:
        return AT_TARGET
    return STEEP_GAP if shape == STEEPEST_AT_LOW else GAP


def _ranked(levers: list[Lever], attempted: set[str]) -> list[Lever]:
    """Sort the rankable levers and number them; leave the rest with ``rank=None``."""
    rankable = [lever for lever in levers if lever.tier in _TIER_ORDER]

    def key(lever: Lever) -> tuple[int, float, int]:
        # The tier decides which quantity orders WITHIN it: tier 0 is placed by the size
        # of the owner's own measured effect, every other tier by the gap it is shown
        # with. The two are never compared to each other — that would be the composite.
        by_tier = lever.finding_effect if lever.tier == PERSONAL_FINDING else lever.gap_fraction
        return (
            _TIER_ORDER.index(lever.tier),
            -(by_tier or 0.0),
            1 if lever.metric in attempted else 0,  # prefer one they have not tried
        )

    ordered = {lever.metric: i + 1 for i, lever in enumerate(sorted(rankable, key=key))}
    placed = [
        lever if lever.metric not in ordered else _with_rank(lever, ordered[lever.metric])
        for lever in levers
    ]
    return sorted(placed, key=lambda lever: (lever.rank is None, lever.rank or 0, lever.metric))


def _with_rank(lever: Lever, rank: int) -> Lever:
    return replace(lever, rank=rank)


# ── the owner state the exclusions read ───────────────────────────────────────


def _blocked_reason(  # noqa: PLR0913 — one exclusion per owner-state input, each named
    metric: str,
    active_metrics: set[str],
    abandoned: dict[str, date],
    recovery: str | None,
    illness: str | None,
    finding: dict | None,
) -> str | None:
    """Why ``metric`` may not be proposed at all, or ``None``.

    The recovery exclusion is ``recovery_guard.hold_reason``, not a rule of this
    module's own: the adapter refuses to RAISE exactly the levers this refuses to
    OFFER, and two copies of "which levers, on what owner state" is how the two
    surfaces came to disagree in the first place.

    The duplicate exclusion asks ``commitment.clashing`` rather than ``in``, so a time
    WINDOW of a substance the owner is already running is off the menu too — one
    behaviour, one commitment (``challenges.commitment``).
    """
    if metric in active_metrics:
        return "already running as a live challenge"
    live = commitment.clashing(metric, active_metrics)
    if live is not None:
        return f"the same behaviour is already a live challenge as `{live}`"
    if metric in abandoned:
        return f"abandoned on {abandoned[metric]} — not re-offered within the cooldown"
    unfounded = _unfounded_window(metric, finding)
    if unfounded is not None:
        return unfounded
    hold = hold_reason(metric, recovery, illness)
    if hold is not None:
        return f"a hard training lever withheld because {hold} [recovery_readiness]"
    return None


def _unfounded_window(metric: str, finding: dict | None) -> str | None:
    """A time window with no personal cutoff behind it may not be offered at all.

    The hour IS the claim. The corpus evidences that late intake degrades sleep — that
    part is Established — but it explicitly refuses to name an hour: [[caffeine_sleep]]'s
    own honesty policy is to "surface the metabolic-variability confound (CYP1A2
    half-life 3-7 h) rather than asserting a universal cutoff hour", and
    [[caffeine_alcohol_cutoff_plan]] frames a cutoff as the owner's *observed* threshold,
    never a metabolic floor. So the only thing that can justify 16:00 over 20:00 for a
    given person is that person's own FDR-controlled finding.

    Without one, offering a window would be inventing precisely the number the evidence
    base declines to state — so it is BLOCKED rather than merely ranked last. Every other
    unranked metric is honestly proposable ("we cannot say what it is worth"); this one is
    not, because the target is not the doubtful part, the hour is.
    """
    source = spec(metric).source
    if not isinstance(source, WindowedManualEntrySource) or finding is not None:
        return None
    notes = " ".join(f"[{note}]" for note in evidence_notes(source.kind))
    return (
        "a cutoff hour is a claim about THIS person and their own data has not found one "
        f"here — the corpus evidences late intake, never a universal hour {notes}"
    )


def _recently_abandoned(cur: Cur, user_id: UUID, tz: str, today: date) -> dict[str, date]:
    """Metrics whose most recent frozen outcome is an abandonment inside the cooldown.

    ``challenge_outcome.ended_at`` is a TIMESTAMPTZ — an INSTANT — while ``today`` is the
    owner's local calendar date, so the instant is resolved in the owner's zone before the
    two are subtracted. A day either side would not change a 60-day cooldown, but this
    repo has shipped two live wrong numbers from exactly this shortcut and the rule here
    is that a calendar date and an instant never meet without a zone between them.

    **Bounded by the cooldown, not by a row count.** The read starts at the first instant
    of the local day ``ABANDON_COOLDOWN_DAYS`` back — the earliest ``ended_on`` that can
    still satisfy the comparison below — so it is exactly as wide as the rule and no
    wider. Nothing outside that span can change an answer: an abandonment older than the
    window is out of cooldown by definition, and any outcome NEWER than a within-window
    abandonment is itself within the window, so the "latest row per metric" reading is
    unchanged. The previous 50-row tail could drop the latest row for a metric and report
    it as never abandoned, re-offering something the owner had dropped.

    **``decided`` is a second set, and it is not bookkeeping.** The rule is "the metric's
    MOST RECENT outcome is an abandonment", and the loop used to mark a metric seen only
    when it recorded an abandonment for it — so a later *completion* did not stop the walk
    and the older abandonment was found underneath it. The docstring said one thing and the
    code did another; the wider read above makes the gap easier to reach, so it is closed
    here rather than left. A metric they walked away from and have since finished is a
    metric they came back to, and the cooldown exists for the ones they did not.
    """
    abandoned: dict[str, date] = {}
    decided: set[str] = set()
    zone = ZoneInfo(tz)
    window_opens = datetime.combine(
        today - timedelta(days=ABANDON_COOLDOWN_DAYS), time.min, tzinfo=zone
    )
    for outcome in ledger.since(cur, user_id, window_opens):
        metric, ended = outcome["metric"], outcome["ended_at"]
        if metric in decided or ended is None:
            continue  # newest-first, so the first row per metric is that metric's latest
        decided.add(metric)
        ended_on = ended.astimezone(zone).date()
        if outcome["status"] == "abandoned" and (today - ended_on).days <= ABANDON_COOLDOWN_DAYS:
            abandoned[metric] = ended_on
    return abandoned


def _attempted_metrics(cur: Cur, user_id: UUID) -> set[str]:
    """Metrics this owner has already committed to at least once (the tie-break).

    A TAIL, deliberately, and the only remaining caller of ``_HISTORY_ROWS``: this orders
    two otherwise equal offers and nothing turns on it, so "in the last fifty outcomes"
    is an honest answer to an honest heuristic. It is not a rule with a time bound in it.
    """
    return {outcome["metric"] for outcome in ledger.recent(cur, user_id, limit=_HISTORY_ROWS)}
