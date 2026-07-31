"""What counts as the SAME commitment — the rule #72 was missing.

CHALLENGES.md §2.1's argument, applied to the one door it was not applied to. Generation
dedupes against the metrics an owner already has live or suggested (``screen``,
``generate._persist``); ``lifecycle.adopt`` checked status, cadence and the per-owner cap
and **did not**. So two suggestions on one metric could both be adopted, which is not two
commitments — it is one behaviour change scored twice: two rows reading the same
``derived_daily`` days, two frozen baselines, two before/afters in the ledger over one
change, and a ``concurrent_challenges`` confound inflated on every *other* outcome whose
window overlaps.

## The rule: one active commitment per BEHAVIOUR, not per (metric, cadence)

The tempting narrower rule is per ``(metric, cadence)`` — a daily steps challenge and a
weekly steps challenge really are different *rules*, and somebody could reasonably want
both. They are refused anyway, for two reasons:

* **The ledger cannot tell them apart.** ``challenge_outcome`` records one metric's
  before→after; two outcomes on ``steps_total`` over overlapping windows are two claims
  about one behaviour change, and there is no cadence field that rescues the attribution.
  §2.1's whole position is that under concurrency attribution is unknowable, and the
  shape of the rule does not change what is knowable.
* **Adopt must not be more permissive than generation.** ``screen`` refuses a second
  proposal on an active metric whatever its cadence. A narrower rule here would reopen
  the same gap through a different door, which is how the gap existed in the first place.

## Why it is wider than "the same metric string" — the windowed metrics

``caffeine_mg`` and ``caffeine_after_16`` are different registry keys reading the *same*
``manual_entry`` rows, one a subset of the other. Adopting both is the §2.1 failure in
its purest form: the late-caffeine series is literally part of the total-caffeine series,
so the two outcomes cannot move independently, and the ledger would publish two
before/afters over one week of drinking less coffee. Two windows on one substance
(``caffeine_after_12`` and ``caffeine_after_20``) are worse still — nested, and both
satisfied by the same behaviour.

So the key is the **source binding**, which is what the metric actually reads. That also
makes the rule maintenance-free: a metric added to ``CHALLENGE_METRICS`` collides with
whatever it reads, without anybody remembering to come here and list it.
"""

from __future__ import annotations

from collections.abc import Iterable

from healthee.challenges.metrics import (
    CHALLENGE_METRICS,
    DerivedSource,
    ManualEntrySource,
    WorkoutCountSource,
    spec,
)
from healthee.challenges.windowed import WindowedManualEntrySource


def commitment_key(metric: str) -> str:
    """The behaviour ``metric`` measures — equal for two metrics reading the same rows.

    Derived from the registry's source binding rather than from a hand-kept table, so a
    metric and any time-window of it are one commitment by construction. The strings are
    internal (they are compared, never displayed), but they are namespaced so a
    ``derived_daily`` metric and a logged kind that happened to share a name could not
    collide by accident.
    """
    source = spec(metric).source
    if isinstance(source, WindowedManualEntrySource | ManualEntrySource):
        return f"log:{source.kind}"
    if isinstance(source, DerivedSource):
        return f"derived:{source.metric}:{source.flag_key or ''}"
    if isinstance(source, WorkoutCountSource):
        return "workout:count"
    raise TypeError(f"{metric!r} has an unclassified source {type(source).__name__}")


def clashing(metric: str, taken: Iterable[str]) -> str | None:
    """The already-spoken-for metric that is the same commitment as ``metric``, or ``None``.

    Returns the OTHER metric's name rather than a boolean because every caller has to say
    which one — a refusal an owner cannot act on ("you already have one of those") is the
    silent-degraded-state standards §Errors forbids, and the coach has to be able to name
    the challenge that is in the way.

    ``metric`` itself counts: when it is already taken, the answer is itself, which is
    #72's own case and reads correctly at every call site.
    """
    key = commitment_key(metric)
    for other in sorted(taken):
        if other in CHALLENGE_METRICS and commitment_key(other) == key:
            return other
    return None


def sharing(metrics: Iterable[str]) -> set[str]:
    """Every registry metric that is the same commitment as one of ``metrics``.

    The set form, for the callers that need to *exclude* rather than *report* — the
    lever menu and the generation prompt, which have to hide a window whose substance is
    already spoken for. Unknown names pass through untouched: a stored row naming a
    metric this build no longer has is still something the owner is running, and
    dropping it from a "taken" set would let a duplicate in.
    """
    known = {m for m in metrics if m in CHALLENGE_METRICS}
    keys = {commitment_key(m) for m in known}
    return set(metrics) | {m for m in CHALLENGE_METRICS if commitment_key(m) in keys}
