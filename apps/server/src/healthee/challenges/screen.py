"""The gates applied to ONE generated proposal — where a challenge is refused.

Split from :mod:`healthee.challenges.generate` so the rules read as rules: that module
decides *when* to ask a model and what to do with the answer, this one decides what a
proposal must be before it may become a commitment somebody keeps for a fortnight.

Nothing here repairs anything. Every function returns either ``None`` (this may ship)
or a sentence saying why not — and the caller drops the proposal and logs the sentence.
That is the whole point of Gate A: legacy's ``_validate`` (:390) silently rewrote a bad
category, defaulted a bad difficulty and stripped bad citations, then persisted the
challenge; each of those repairs files a claim the model never made. A rejected proposal
costs one entry in a feed. A repaired one costs the honesty contract.

The order of the checks is not arbitrary — shape before vocabulary before evidence
before arithmetic — so the reason reported is the most fundamental one that is true.
"""

from __future__ import annotations

from healthee.challenges import commitment, gen_prompt
from healthee.challenges.bounds import Calibration, copy_issue, target_issue
from healthee.challenges.gen_prompt import MAX_WINDOW_DAYS, MIN_WINDOW_DAYS
from healthee.challenges.metrics import CHALLENGE_METRICS, COMPARATORS
from healthee.insights import manifest
from healthee.insights.answer_text import extract_citations

CalibrationMap = dict[tuple[str, str], Calibration]

_REQUIRED_FIELDS = (
    "title",
    "why",
    "expected_outcome",
    "how_to",
    "category",
    "difficulty",
    "metric",
    "comparator",
    "target_value",
    "cadence",
    "window_days",
    "research_note_ids",
)

# The fields whose numerals are checked against the stored target. ``how_to`` is absent
# deliberately — ``bounds.copy_issue`` argues why a method number is not a rival target.
_COPY_FIELDS = ("title", "why", "expected_outcome")


def screen(
    payload: dict,
    calibrations: CalibrationMap,
    taken: set[str],
    max_new: int,
    blocked: dict[str, str] | None = None,
) -> tuple:
    """Apply every gate to a parsed payload. Returns (what may ship, why the rest may not).

    ``taken`` is the set of metrics already spoken for — the owner's live challenges plus
    whatever this batch has already accepted, so a batch cannot duplicate itself either.
    It is copied, never mutated in the caller's hands.

    ``blocked`` is WP-C3c's lever exclusions (``levers.LeverAnalysis.blocked_metrics``):
    a metric they abandoned last month, or a hard training lever while they are
    under-recovered. It is enforced HERE rather than only asked for in the prompt for the
    same reason the band is — legacy's prompt told itself to route around abandons and
    never checked, and an instruction nobody enforces is decoration.
    """
    proposals = payload.get("challenges")
    if not isinstance(proposals, list):
        return [], ["payload has no 'challenges' array"]
    claimed = set(taken)
    accepted: list[dict] = []
    issues: list[str] = []
    for index, proposal in enumerate(proposals):
        issue = proposal_issue(proposal, calibrations, claimed, blocked or {})
        if issue is not None:
            issues.append(f"challenge[{index}]: {issue}")
            continue
        accepted.append(proposal)
        claimed.add(proposal["metric"])
        if len(accepted) >= max_new:
            break
    return accepted, issues


def proposal_issue(
    proposal: object,
    calibrations: CalibrationMap,
    taken: set[str],
    blocked: dict[str, str] | None = None,
    *,
    bind_target: bool = True,
) -> str | None:
    """The first reason one proposal may not ship, or ``None`` if it may.

    ``bind_target=False`` skips Gate A's band check and ONLY that — every other rule
    below still applies, the copy check included. It exists for WP-C4b: a ladder's rung 3
    is *meant* to sit above today's band, that is what a ladder IS, so binding Gate A to
    every rung at design time would reject every legitimate program. Those rungs are
    bounded at ACTIVATION instead, by ``rung.recalibrated_target`` reading this same band
    at the moment the rung starts — so no rung is ever *run* outside the owner's
    then-current band, which is the property that actually protects them. See
    ``challenges/program_screen.py`` for the shape gates that take Gate A's place at
    design time.

    ``copy_issue`` is deliberately NOT skipped with it: it only needs the band's low end
    as a *numeral threshold* ("a number this big must be the target"), so it works above
    the band exactly as it does inside it — and a rung whose prose names a number the row
    does not hold is the same lie whatever rung it is.
    """
    structural = _structural_issue(proposal)
    if structural is not None:
        return structural
    if not isinstance(proposal, dict):  # unreachable — `_structural_issue` proved it
        return "not an object"
    duplicate = commitment.clashing(proposal["metric"], taken)
    if duplicate == proposal["metric"]:
        return f"{proposal['metric']} already has a live or proposed challenge"
    if duplicate is not None:
        # Not the same metric, but the same rows: `caffeine_after_20` is a slice of
        # `caffeine_mg`, so proposing both offers one behaviour change twice
        # (`challenges.commitment`).
        return f"{proposal['metric']} is the same behaviour as {duplicate}, which already has one"
    off_menu = (blocked or {}).get(proposal["metric"])
    if off_menu is not None:
        return f"{proposal['metric']} is not on this owner's menu: {off_menu}"
    grade = _grade_issue(proposal["research_note_ids"])
    if grade is not None:
        return grade
    calibration = calibrations.get((proposal["metric"], proposal["cadence"]))
    if calibration is None:
        return f"{proposal['metric']}/{proposal['cadence']} is not a calibratable pair"
    target = float(proposal["target_value"])
    out_of_band = target_issue(calibration, target) if bind_target else None
    return out_of_band or _copy_issue(proposal, calibration, target)


def _copy_issue(proposal: dict, calibration: Calibration, target: float) -> str | None:
    """Gate A's second half: the prose may not name a number the row does not hold."""
    for field in _COPY_FIELDS:
        issue = copy_issue(calibration, target, str(proposal.get(field) or ""))
        if issue is not None:
            return issue
    return None


def _structural_issue(proposal: object) -> str | None:
    """Shape, vocabulary and range — the checks that make the row well-formed.

    An unknown metric, comparator, cadence, category or difficulty is REFUSED, never
    defaulted. Legacy rewrote a bad category to "fitness" and a bad difficulty to
    "standard", which files a label the model never chose — and difficulty is half of
    what an outcome means once the ledger groups by it (``challenge_outcome.difficulty``).

    ``cadence`` is checked by the calibration lookup rather than here: the map holds
    exactly the generatable pairs, so an ungeneratable cadence is reported as the missing
    pair it is, with the metric named (``bounds.GENERATABLE_CADENCES``).
    """
    if not isinstance(proposal, dict):
        return "not an object"
    missing = [f for f in _REQUIRED_FIELDS if f not in proposal]
    if missing:
        return f"missing {missing}"
    if proposal["metric"] not in CHALLENGE_METRICS:
        return f"{proposal['metric']!r} is not a trackable challenge metric"
    if proposal["comparator"] not in COMPARATORS:
        return f"comparator {proposal['comparator']!r} is not one of {sorted(COMPARATORS)}"
    if proposal["category"] not in gen_prompt.CATEGORIES:
        return f"category {proposal['category']!r} is not in the vocabulary"
    if proposal["difficulty"] not in gen_prompt.DIFFICULTIES:
        return f"difficulty {proposal['difficulty']!r} is not in the vocabulary"
    return _numeric_issue(proposal) or _citation_issue(proposal)


def _numeric_issue(proposal: dict) -> str | None:
    """``target_value`` and ``window_days`` must be real numbers in a sane range."""
    try:
        target = float(proposal["target_value"])
        window = int(proposal["window_days"])
    except (TypeError, ValueError):
        return "target_value/window_days are not numbers"
    if target <= 0:
        return "target_value must be positive"
    if not MIN_WINDOW_DAYS <= window <= MAX_WINDOW_DAYS:
        return f"window_days {window} is outside {MIN_WINDOW_DAYS}-{MAX_WINDOW_DAYS}"
    return None


def _citation_issue(proposal: dict) -> str | None:
    """Every cited id must exist, and ``why`` must carry one INLINE.

    The choke point's blocking validator has already rejected the whole response for a
    fabricated inline id; this is the per-proposal half of cite-or-refuse, the same shape
    as ``jobs.recs._rec_ok`` — a challenge whose ``research_note_ids`` array names a note
    nobody can look up is dropped even though its prose validated.

    The inline check goes through ``answer_text.extract_citations``, the ONE citation
    parser the validator itself uses, so "carries a citation" cannot come to mean two
    different things in two places. It also gets the ``[personal_finding:…]`` distinction
    for free: a personal pattern is not a note id and cannot satisfy this.
    """
    note_ids = proposal.get("research_note_ids") or []
    if not isinstance(note_ids, list) or not note_ids:
        return "no research_note_ids — a challenge with no evidence behind it does not ship"
    unknown = [n for n in note_ids if n not in manifest.note_ids()]
    if unknown:
        return f"cites ids that do not exist in the manifest: {sorted(unknown)}"
    cited, _ = extract_citations(str(proposal.get("why") or ""))
    if not cited:
        return "`why` carries no inline [note_id]"
    return None


def _grade_issue(note_ids: list[str]) -> str | None:
    """The cited evidence must PROVE at least Probable — the floor an acting surface has.

    A challenge is a commitment for the weeks ahead, so ``jobs.recs._provable_grade``'s
    reasoning applies with more force, not less: there is no honest label for
    Emerging-or-weaker evidence on a surface whose purpose is to get somebody to change
    what they do. There is nothing to correct DOWN here the way a rec's self-declared
    grade is corrected — a challenge declares no grade, so the manifest is the only
    source and the model has nothing to overclaim.
    """
    ranks = [manifest.GRADE_RANK.get(manifest.grade_of(n) or "", 0) for n in note_ids]
    if min(ranks) < manifest.MIN_ACTIONABLE_RANK:
        return "cites evidence weaker than Probable — too weak to drive a commitment"
    return None
