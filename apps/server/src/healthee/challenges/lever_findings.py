"""Which of the owner's discovered patterns implicate which trackable metric.

Split from :mod:`healthee.challenges.levers` because it answers a different question and
changes for a different reason (standards §"a file has one reason to change"): that module
decides the ORDER of the levers, this one decides whether the correlation engine has said
anything about a given one at all.

The link has to be made explicitly because the two vocabularies do not match. The
``finding`` table speaks the derive layer's names (``sleep_regularity_index``) and the
substances the manual log records (``caffeine``); the challenge registry speaks its own
shorthand (``sri``, ``caffeine_mg``). The mapping is derived FROM the registry's source
binding wherever it can be, so a metric added to ``CHALLENGE_METRICS`` is linked without
anybody remembering to come here.
"""

from __future__ import annotations

from uuid import UUID

from healthee.analytics.finding import significant_findings
from healthee.challenges.metrics import (
    CHALLENGE_METRICS,
    DerivedSource,
    ManualEntrySource,
    spec,
)
from healthee.challenges.windowed import WindowedManualEntrySource
from healthee.derive._common import Cur
from healthee.read.findings import is_trivial_finding


def findings_by_metric(cur: Cur, user_id: UUID) -> dict[str, dict]:
    """The strongest non-trivial FDR-significant finding implicating each metric.

    ``is_trivial_finding`` is the read layer's rule, reused rather than restated: a
    steps↔distance correlation is arithmetic, not a lever, and there must not be two
    answers to "is this finding real" in one codebase.
    """
    best: dict[str, dict] = {}
    for finding in significant_findings(cur, user_id, limit=50):
        if is_trivial_finding(finding):
            continue
        for metric in CHALLENGE_METRICS:
            if not implicates(finding, metric):
                continue
            held = best.get(metric)
            if held is None or abs(finding["effect_size"]) > abs(held["effect_size"]):
                best[metric] = finding
    return best


def implicates(finding: dict, metric: str) -> bool:
    """Does ``finding`` name ``metric`` on its INTERVENTION side?

    Direction matters. An ``event_effect`` or a ``personal_cutoff`` has an outcome side
    (``metric_a`` / ``metric_b`` — the thing that moved) and an intervention side (the
    substance). Only the intervention is a lever: "caffeine after 16:00 costs you sleep"
    argues for a caffeine challenge, not a sleep-duration one. A ``pairwise_lag`` has no
    such asymmetry, so either side may be the lever.

    A WINDOWED metric is matched by EQUALITY on that intervention side, and nothing
    looser. Its registry key is byte-identical to the ``metric_a`` the cutoff finder
    writes (``challenges.windowed.metric_key``), so "does their own data name this
    window" is a string comparison rather than a prefix rule — and a prefix rule is
    exactly what would go wrong here, because ``caffeine_after_12`` and
    ``caffeine_after_22`` are different claims about the same person and a finding at
    one of them says nothing about the other.
    """
    if isinstance(spec(metric).source, WindowedManualEntrySource):
        return finding.get("metric_a") == metric
    tokens = finding_tokens(metric)
    if not tokens:
        return False
    if finding["kind"] == "pairwise_lag":
        return bool(tokens & {finding.get("metric_a"), finding.get("metric_b")})
    event = finding.get("event_kind")
    outcome_of = str(finding.get("metric_a") or "")
    return event in tokens or any(outcome_of.startswith(f"{t}_after_") for t in tokens)


def finding_tokens(metric: str) -> frozenset[str]:
    """The names a finding would use for ``metric``'s underlying series or substance."""
    if metric in _FINDING_ALIASES:
        return _FINDING_ALIASES[metric]
    source = spec(metric).source
    if isinstance(source, DerivedSource):
        return frozenset({source.metric})
    if isinstance(source, ManualEntrySource):
        return frozenset({source.kind})
    return frozenset()  # `workouts_week` counts rows; the analytics layer has no series


# `tst_min`'s registry source is the 4-dim sleep row (it reads a FLAG of it), but the
# correlation engine correlates the duration series under its own name. The alias keeps
# the link to sleep DURATION and refuses the composite, which is a different quantity.
_FINDING_ALIASES: dict[str, frozenset[str]] = {"tst_min": frozenset({"tst_min"})}


def finding_token(finding: dict) -> str:
    """The ``[personal_finding:<token>]`` name — the same one the context sections use."""
    return str(finding.get("metric_a") or finding.get("kind") or "finding")
