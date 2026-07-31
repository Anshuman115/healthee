"""The generation inputs the grounded-ask choke point does not already supply.

CHALLENGES.md §5.1 grounds generation on three inputs — corpus · the owner's data ·
their discovered patterns. Two and a half of those arrive for free, because generation
runs through ``insights.grounded_ask``: the choke point ranks the corpus by manifest
relevance and builds the v2-native context (today snapshot, trends, sleep sessions with
physiology overlays, manual logs, personal baselines, anomalies, and the FDR-controlled
personal findings — including the ``analytics/cutoffs`` cutoffs — already tokenised as
``[personal_finding:…]``). Rebuilding any of that here would be a second definition of
the owner's own numbers.

This module adds only what generation needs and no other surface does:

0. **The lever ranking** (WP-C3c, ``levers``) — which metric this owner actually has room
   in, ranked deterministically with each gap, target and citation shown. It goes FIRST
   because it is the instruction the rest of the context constrains: the calibration
   table says how far a target may move, the lever table says which metric is worth
   moving at all.
1. **The calibration table** — for every (metric, cadence) pair, the owner's own
   baseline and the exact target range Gate A will accept, in that metric's units. This
   is the honest half of the "instruct AND enforce" fix (§5.1): legacy instructed
   calibration in prose and never checked it, so it shipped 12,000-step targets; we put
   the enforced band in front of the model, which makes an in-band proposal the easy
   path rather than a lucky one.
2. **Sleep timing statistics** — median onset, its spread, and how many nights sit far
   off pattern. The choke point's sleep section carries per-night rows; the aggregate is
   what turns "this person sleeps 3.7 h" into "offer them a REGULARITY challenge, not a
   duration one", which §5.1 names as the judgement call a rules table cannot encode.
3. **Challenge history** — what is live (never duplicate it) and what the frozen ledger
   says happened last time.

## What is deliberately withheld from the model

The outcome ledger's ``co_occurring`` block is NOT rendered. Legacy fed per-challenge
"downstream" deltas on OTHER metrics back into generation while up to four challenges
ran at once (§2.1, the biggest fix mandate) — the numbers exist in the ledger, stripped
of the causal claim, and handing them to a generator is how they get the claim back.
Outcomes on the challenge's OWN target metric are a fair before/after and are rendered;
anything below ``data_confidence='ok'`` is rendered WITH that label so the model cannot
read two logged days as a result.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.challenges import ledger, levers, store
from healthee.challenges.bounds import GENERATABLE_CADENCES, Calibration, calibrate
from healthee.challenges.metrics import CHALLENGE_METRICS
from healthee.challenges.scales import ROUND_STEP
from healthee.derive._common import Cur
from healthee.derive.robust import median

# How far back the sleep-timing aggregate looks, and the fewest nights that make a
# median bedtime a pattern rather than an anecdote. Verbatim from legacy `_build_context`.
_TIMING_DAYS = 28
_MIN_TIMING_NIGHTS = 5

# Minutes past 18:00 — the origin legacy anchored sleep onset to, so that a bedtime
# either side of midnight lands on one continuous scale instead of wrapping to 0.
_ONSET_ORIGIN_MIN = 18 * 60
_MINUTES_PER_DAY = 24 * 60

# A night this far from the owner's own median onset is "off pattern" (legacy: >2 h).
_OFF_PATTERN_MIN = 120

# How many frozen outcomes generation reads back. The ledger endpoint pages history;
# this is the tail that can still say anything about who this person is now.
_HISTORY_LIMIT = 12

CalibrationMap = dict[tuple[str, str], Calibration]


def owner_calibrations(cur: Cur, user_id: UUID, tz: str, today: date) -> CalibrationMap:
    """Gate A's verdict for every (metric, cadence) pair, computed ONCE per generation.

    The same objects are rendered into the prompt and used to judge what comes back, so
    the band the model was shown and the band its proposal is checked against are
    provably the same numbers — not two reads that could disagree if a day rolled over
    between them.
    """
    return {
        (metric, cadence): calibrate(cur, user_id, tz, metric, cadence, today)
        for metric in CHALLENGE_METRICS
        for cadence in sorted(GENERATABLE_CADENCES)
    }


def calibration_section(calibrations: CalibrationMap) -> str:
    """The allowed target range per (metric, cadence), in the metric's own units."""
    lines = [
        "## YOUR CALIBRATION TABLE — the target range each challenge must land in",
        "Baselines are the owner's OWN trailing 7 days, read by the same estimator that",
        "will be frozen onto the challenge when they adopt it. A target outside the",
        "allowed range is REJECTED and the challenge never reaches them — there is no",
        "clamping, so an out-of-range number costs the whole proposal.",
        "",
        "| metric | cadence | unit | your baseline | allowed target | round to |",
        "|---|---|---|---|---|---|",
    ]
    unavailable: list[str] = []
    for (metric, cadence), cal in sorted(calibrations.items()):
        spec_ = CHALLENGE_METRICS[metric]
        if cal.band is None:
            unavailable.append(f"- `{metric}` ({cadence}): UNAVAILABLE — {cal.refusal}")
            continue
        lines.append(
            f"| {metric} | {cadence} | {spec_.unit or '—'} | {cal.baseline:g} "
            f"({cal.baseline_days}d) | {cal.band.low:g}–{cal.band.high:g} | "
            f"{ROUND_STEP.get(metric, 1):g} |"
        )
    if unavailable:
        lines += [
            "",
            "UNAVAILABLE metrics — do NOT propose a challenge on any of these. There is "
            "not enough of the owner's own data to calibrate a target, and a target we "
            "cannot calibrate is a number we invented:",
            *unavailable,
        ]
    return "\n".join(lines)


def lever_section(analysis: levers.LeverAnalysis) -> str:
    """Where this owner has the most to gain, ranked deterministically (WP-C3c).

    The model is shown the ORDER and the numbers behind it, never asked to compute
    either: ``levers`` decides which metric matters and this renders its reasoning so
    the copy can be written around a gap the owner can be told about honestly.
    """
    header = ["## YOUR BIGGEST LEVERS — where the evidence says this owner has the most to gain"]
    ranked = analysis.ranked()
    if not ranked:
        # Rendered even when it is empty, because the task text tells the model to start
        # from this section: a heading that silently vanishes leaves an instruction
        # pointing at nothing, and a model that cannot find the ranking will invent a
        # reason to prefer one metric. Saying "we could not rank anything" is both true
        # and the more useful instruction.
        return "\n".join(
            header
            + [
                "NOTHING COULD BE RANKED for this owner: no metric has both a usable "
                "baseline and a population target we can cite. Choose from the "
                "calibration table on its own merits and do not claim that one metric "
                "matters more than another — we have no basis for saying so."
            ]
            + _lever_notes(analysis)
        )
    lines = header + [
        "Computed deterministically from their baselines, the corpus targets and their own",
        "FDR-controlled findings. **Author for the top of this list.** Each row's `target`",
        "cites the note it came from — cite that note when you write about the gap.",
        "",
        "| # | metric | where they are | evidence target | gap | why it ranks here |",
        "|---|---|---|---|---|---|",
        *(_lever_row(lever) for lever in ranked),
    ]
    return "\n".join(lines + _lever_notes(analysis))


def _lever_row(lever: levers.Lever) -> str:
    """One ranked lever, with the quantity that placed it shown beside it."""
    where = "—" if lever.baseline is None else f"{lever.baseline:g}/{lever.cadence[:-2]}"
    target = "—" if lever.target is None else f"{lever.target:g} [{lever.target_note}]"
    gap = "—" if lever.gap is None else f"{lever.gap:+g}"
    return f"| {lever.rank} | {lever.metric} | {where} | {target} | {gap} | {_reason(lever)} |"


def _reason(lever: levers.Lever) -> str:
    """The named rule that placed this lever — never a score, always a sentence."""
    if lever.tier == levers.PERSONAL_FINDING:
        effect = f"{lever.finding_effect:.2f}" if lever.finding_effect else "?"
        return (
            f"YOUR OWN measured pattern `[personal_finding:{lever.finding}]` "
            f"(|effect| {effect}, single-subject and observational — not research)"
        )
    if lever.tier == levers.STEEP_GAP:
        return f"below target on a curve that is steepest at the bottom [{lever.curve_note}]"
    if lever.tier == levers.GAP:
        return f"below the evidence target [{lever.curve_note or lever.target_note}]"
    return "at or past the evidence target — little left to gain here"


def _lever_notes(analysis: levers.LeverAnalysis) -> list[str]:
    """The two honest negatives: what is off the menu, and what we cannot place."""
    lines: list[str] = []
    if analysis.illness or analysis.recovery:
        state = f"recovery band `{analysis.recovery}`" if analysis.recovery else "recovery unknown"
        illness = ", ILLNESS FLAG ACTIVE" if analysis.illness else ""
        lines += ["", f"Owner state used above: {state}{illness}."]
    blocked = analysis.blocked_metrics()
    if blocked:
        lines += [
            "",
            "OFF THE MENU — a proposal on any of these is REJECTED before it reaches them:",
            *(f"- `{metric}`: {reason}" for metric, reason in sorted(blocked.items())),
        ]
    unplaceable = sorted(lever.metric for lever in analysis.levers if lever.tier == levers.UNRANKED)
    if unplaceable:
        lines += [
            "",
            "NOT RANKED — no population dose-response evidence exists for these, so we "
            "cannot say what moving them is worth. Proposing one is allowed and it is not "
            "where the return is; if you do, do not imply a health payoff we cannot cite: "
            + ", ".join(f"`{m}`" for m in unplaceable),
        ]
    return lines


def sleep_timing_section(cur: Cur, user_id: UUID, tz: str, today: date) -> str:
    """Median sleep onset, its spread, and the count of off-pattern nights.

    Computed in the OWNER's zone (``AT TIME ZONE %s``, parameterized) — legacy inlined
    ``Asia/Kolkata`` here, which is the calendar-date-vs-instant bug class that has
    already shipped two wrong numbers in this repo.
    """
    cur.execute(
        "SELECT EXTRACT(HOUR FROM (start_ts AT TIME ZONE %s))::int * 60 "
        "     + EXTRACT(MINUTE FROM (start_ts AT TIME ZONE %s))::int "
        "FROM sleep_session WHERE user_id = %s AND kind = 'main' "
        "  AND (start_ts AT TIME ZONE %s)::date > %s ORDER BY start_ts",
        (tz, tz, user_id, tz, today - timedelta(days=_TIMING_DAYS)),
    )
    onsets = [float((int(row[0]) - _ONSET_ORIGIN_MIN) % _MINUTES_PER_DAY) for row in cur.fetchall()]
    if len(onsets) < _MIN_TIMING_NIGHTS:
        return ""
    return _timing_lines(onsets, tz)


def _timing_lines(onsets: list[float], tz: str) -> str:
    """Render the timing aggregate. ``onsets`` are minutes past 18:00, local."""
    centre = median(onsets)  # the ONE median (`derive.robust`), never a second one
    spread = (sum((o - centre) ** 2 for o in onsets) / len(onsets)) ** 0.5
    clock = int(_ONSET_ORIGIN_MIN + centre) % _MINUTES_PER_DAY
    off_pattern = sum(1 for o in onsets if abs(o - centre) > _OFF_PATTERN_MIN)
    return (
        f"## SLEEP TIMING (last {_TIMING_DAYS} days, {tz})\n"
        f"- Typical onset ~{clock // 60:02d}:{clock % 60:02d} local "
        f"(spread {spread:.0f} min; {off_pattern}/{len(onsets)} nights more than "
        f"{_OFF_PATTERN_MIN // 60} h off their own median)."
    )


def history_section(cur: Cur, user_id: UUID) -> str:
    """What is live right now, and what the frozen ledger says about what came before."""
    active = store.list_by_status(cur, user_id, ("active",))
    outcomes = ledger.recent(cur, user_id, limit=_HISTORY_LIMIT)
    if not active and not outcomes:
        return ""
    lines = ["## CHALLENGE HISTORY"]
    if active:
        lines.append("Currently ACTIVE — do NOT propose anything on these metrics:")
        lines += [
            f"- {c['title']}: {c['metric']} {c['comparator']} {float(c['target_value']):g} "
            f"({c['cadence']})"
            for c in active
        ]
    if outcomes:
        lines += [
            "",
            "FROZEN OUTCOMES (the owner's OWN target metric, before → after). These are "
            "single-subject observations of what happened while they held a commitment, "
            "not research: reference one as `[personal_finding:challenge_outcome]` and "
            "still attach a real `[note_id]` for any interpretive claim built on it. A "
            "row marked insufficient_data proves NOTHING and must not be built on.",
            *(_outcome_line(o) for o in outcomes),
        ]
    return "\n".join(lines)


def _outcome_line(outcome: dict) -> str:
    """One ledger row, carrying its own confidence label (never stripped from it)."""
    improvement = outcome.get("improvement_pct")
    moved = "no comparable before/after" if improvement is None else f"{improvement:+g}%"
    adherence = outcome.get("adherence")
    kept = "" if adherence is None else f", kept on {round(adherence * 100)}% of days"
    return (
        f"- {outcome['status']}: {outcome['metric']} target "
        f"{float(outcome['target'] or 0):g} ({outcome['cadence']}) → {moved}{kept} "
        f"[{outcome['data_confidence']}]"
    )


def build_generation_context(
    cur: Cur, user_id: UUID, tz: str, today: date, active_metrics: set[str]
) -> tuple[str, CalibrationMap, levers.LeverAnalysis]:
    """The challenge-specific half of the prompt, plus the rules it promises.

    All three are returned together on purpose: the caller must judge proposals with the
    SAME calibrations AND the same lever analysis it showed the model. Two reads could
    disagree — a day could roll over, a challenge could be adopted — and then the prompt
    would advertise a lever the gate rejects, which reads to the model as a broken
    instruction and to the owner as an empty feed with no reason.

    The lever section comes FIRST because it is the instruction; the calibration table
    below it is the constraint on carrying that instruction out.
    """
    calibrations = owner_calibrations(cur, user_id, tz, today)
    analysis = levers.analyse(cur, user_id, tz, today, calibrations, active_metrics)
    sections = [
        lever_section(analysis),
        calibration_section(calibrations),
        sleep_timing_section(cur, user_id, tz, today),
        history_section(cur, user_id),
    ]
    return "\n\n".join(s for s in sections if s), calibrations, analysis
