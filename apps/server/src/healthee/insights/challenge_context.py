"""The coach's challenge + outcome-ledger context — this person's OWN evidence (WP-C5).

COACH_ROADMAP C2, CHALLENGES.md §2.1 / §7 decision 1, INTELLIGENCE §4. Legacy built the
outcome ledger and never connected it to the coach: the flagship surface could see what
somebody was *doing* and never what had actually *worked* for them. This is that wire —
and the shape of the wire is where the honesty lives, because a caveat the model is
merely asked to respect is a caveat the model can drop.

## Three caveats, enforced by what is in the prompt rather than by asking

1. **A co-occurring delta never enters the context.** An outcome carries the movement of
   OTHER metrics over the same window with ``attribution: "none"`` and the count of
   concurrent commitments (``ledger._co_occurring``). Rendering those numbers and asking
   the model not to attribute them is precisely the arrangement §2.1 calls the biggest
   fix mandate: legacy's prose said "observational" while its data structure implied
   cause. The numbers are simply not here, so no wording can lift them out of context.
   ``gen_context`` withholds them from the generator for the same reason — this is that
   one decision applied to the second reader, not a new one.
2. **An ``insufficient_data`` outcome carries no numbers.** It is still listed, because a
   commitment that ended is a fact and hiding it invites the model to invent what
   happened — but its before/after is omitted entirely, so there is no figure to quote. A
   confidence LABEL beside a number is a caveat; an absent number is a guarantee.
3. **A confound travels with the claim it qualifies.** Illness days, concurrency and
   regression-to-the-mean are rendered on the same line as the improvement, never in a
   separate block a summary can leave behind.

Everything in the evidence block is cited as ``[personal_finding:challenge_outcome]`` —
single-subject and observational. The validator already keeps that token distinct from a
population ``[note_id]`` and refuses to let one substitute for the other
(``validator``'s rule 2), so "distinguished from research" is enforced downstream too.

## What is NOT here

Live progress. ``lifecycle.list_challenges`` computes it, and it also runs
``suggest_adaptation`` per active challenge; the coach does not need either to talk
about a commitment, and it has ``query_metric`` for the number. The coach never adapts a
live target in any case — that is the deterministic engine's job (§5.2).
"""

from __future__ import annotations

from uuid import UUID

from healthee.challenges import ledger, lifecycle, store
from healthee.derive._common import Cur

# How many frozen outcomes reach the coach. Same reasoning as ``gen_context``'s: the
# ledger endpoint pages history, and this is the tail that can still say something about
# who this person is now.
LEDGER_LIMIT = 12


def challenge_section(cur: Cur, user_id: UUID) -> str:
    """The owner's commitments and their frozen outcomes as markdown, or ``''``.

    Takes the caller's cursor: ``coach_context`` already holds an owner-scoped
    transaction for the recovery block, and opening a second pooled connection inside
    one that is already held is how the pool deadlocks (standards §Performance).
    """
    active = store.list_by_status(cur, user_id, ("active",), limit=lifecycle.MAX_ACTIVE)
    suggested = store.list_by_status(cur, user_id, ("suggested",))
    outcomes = ledger.recent(cur, user_id, limit=LEDGER_LIMIT)
    blocks = [_commitments(active, suggested), _evidence(outcomes), _unusable(outcomes)]
    return "\n\n".join(block for block in blocks if block)


def _commitments(active: list[dict], suggested: list[dict]) -> str:
    """What is running and what is on the menu — with the ids ``adopt_challenge`` needs."""
    if not active and not suggested:
        return ""
    lines = ["## THEIR CHALLENGES"]
    if active:
        lines += [
            "Running right now. The engine scores these from their own data and "
            "recalibrates them deterministically — you never move a live target, and you "
            "never claim progress you did not read from a tool:",
            *(_row(challenge) for challenge in active),
        ]
    else:
        lines.append("Running right now: nothing.")
    if suggested:
        lines += [
            "",
            "SUGGESTED — built for them but NOT started. Call `adopt_challenge` with the "
            "id below only if they ask to start one:",
            *(_row(challenge) for challenge in suggested),
        ]
    return "\n".join(lines)


def _row(challenge: dict) -> str:
    """One challenge, as the stored rule it actually is."""
    return (
        f"- #{int(challenge['id'])} {challenge['title']}: {challenge['metric']} "
        f"{challenge['comparator']} {float(challenge['target_value']):g} "
        f"({challenge['cadence']}, {int(challenge['window_days'])}d)"
    )


def _evidence(outcomes: list[dict]) -> str:
    """The outcomes we are willing to let the coach build on — ``data_confidence='ok'``."""
    usable = [o for o in outcomes if o.get("data_confidence") == "ok"]
    if not usable:
        return ""
    return "\n".join(
        [
            "## WHAT HAS ACTUALLY WORKED FOR THIS PERSON — frozen challenge outcomes",
            "Their own measured before → after on the metric they committed to. This is "
            "the strongest honest motivator you have and it is THEIRS, not a study: "
            "reference one as `[personal_finding:challenge_outcome]`, say plainly that it "
            "is single-subject and observational, and still attach a real `[note_id]` for "
            "any interpretive claim you build on it. What ELSE moved during those windows "
            "is deliberately absent — with other commitments running at the same time it "
            "cannot be attributed to any one of them, so there is nothing to quote and "
            "nothing to imply.",
            *(_outcome_line(outcome) for outcome in usable),
        ]
    )


def _outcome_line(outcome: dict) -> str:
    """One usable outcome: the claim and, inseparably, what qualifies it."""
    improvement = outcome.get("improvement_pct")
    moved = "no comparable before/after" if improvement is None else f"{improvement:+g}%"
    adherence = outcome.get("adherence")
    kept = "" if adherence is None else f", kept on {round(float(adherence) * 100)}% of days"
    return (
        f"- {outcome['status']}: {outcome['metric']} target "
        f"{float(outcome['target'] or 0):g} ({outcome['cadence']}) over "
        f"{outcome.get('days_active')}d → {moved} vs their own frozen baseline{kept}"
        f"{_caveats(outcome)}"
    )


def _caveats(outcome: dict) -> str:
    """The confound flags, rendered onto the same line as the number they qualify."""
    confounds = outcome.get("confounds") or {}
    bits: list[str] = []
    illness = int(confounds.get("illness_days") or 0)
    if illness:
        bits.append(f"{illness} day(s) with an illness flag inside the window")
    concurrent = int(confounds.get("concurrent_challenges") or 0)
    if concurrent:
        bits.append(f"{concurrent} other commitment(s) ran alongside it")
    bits.extend(_regression_caveat(confounds.get("regression_to_mean") or {}))
    return "" if not bits else " — caveats: " + "; ".join(bits)


def _regression_caveat(regression: dict) -> list[str]:
    """Was the starting point itself abnormal — or could we not tell? Both are said.

    An unassessed confound reported as no confound reads as a check that passed
    (``confounds``'s module docstring), so the two states stay distinguishable here.
    """
    if not regression:
        return []
    if not regression.get("assessed"):
        return [f"regression to their own mean could not be assessed ({regression.get('reason')})"]
    if regression.get("at_risk"):
        return [
            "their starting point was itself abnormal for them, so part of this move is "
            "drift back toward their own norm rather than the commitment"
        ]
    return []


def _unusable(outcomes: list[dict]) -> str:
    """Outcomes that happened but prove nothing — listed WITHOUT their numbers."""
    thin = [o for o in outcomes if o.get("data_confidence") != "ok"]
    if not thin:
        return ""
    return "\n".join(
        [
            "NOT EVIDENCE — these commitments ended, but one side of the comparison had "
            "too few measured days for a before/after to mean anything. Their numbers are "
            "deliberately not in this context and there is nothing here to cite: if one "
            "comes up, say only that we do not have enough data to say what happened.",
            *(
                f"- {outcome['status']}: {outcome['metric']} ({outcome['cadence']}) — "
                f"{outcome.get('data_confidence')}"
                for outcome in thin
            ),
        ]
    )
