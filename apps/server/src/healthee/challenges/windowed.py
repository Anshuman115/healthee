"""The time predicate: "X logged at or after HH:00, in the OWNER's own clock".

The registry's closing paragraph used to end with an absence — a ``ChallengeMetric``
yields one number per owner-day and had no "…logged after HH:MM" dimension, so the
challenge a personal cutoff naturally produces ("no caffeine after 16:00") could not be
expressed and WP-C5's ``create_challenge`` refused it outright. This module is that
dimension. It is deliberately NOT a second kind of challenge: a windowed metric is an
ordinary registry entry with an ordinary ``good="down"`` cap on it, so ``evaluate``,
``bounds``, ``adapt``, ``levers``, ``ledger`` and the lifecycle score it with the code
they already had.

## The hours and the substances are the FINDER's, not a second list

``WINDOW_HOURS`` and ``WINDOW_SUBSTANCES`` come from ``analytics.cutoffs``, which is the
module that decides what a cutoff can be about and at what hour it can sit. A windowed
metric's key is therefore *exactly* the ``metric_a`` that finder writes onto a
``personal_cutoff`` finding (``caffeine_after_16``), which is what lets
``lever_findings`` link a finding to a challenge by equality rather than by a parser
that could drift. Two lists of cutoff hours is two definitions of the same thing
(CLAUDE.md).

## ZERO vs UNLOGGED — the honesty crux of the whole feature

``ManualEntrySource`` zero-fills: a day with no caffeine row reads as 0 mg, and its own
docstring accepts that trade because a cap is otherwise unscoreable for the owner who
genuinely abstained. **A window may not make that trade**, and the reason is that the
failure runs the wrong way. "No caffeine after 16:00" is satisfied *by absence*, so an
owner who simply stops logging scores a perfect week — silence rendered as compliance,
on the one surface whose entire purpose is to refuse an optimistic guess.

A window has a discriminator the daily total does not: **the owner's own logging on that
day**. If they logged an 08:00 coffee, they were logging — so "nothing after 16:00" is
evidence. If they logged nothing of that kind at all, we know nothing about their
evening. So the rule is:

* at least one qualifying entry of that kind on that local day ⇒ the day is MEASURED,
  and the value is the sum of whatever fell inside the window (**0.0 is a real zero**);
* no entry of that kind at all ⇒ the day is **absent from the series**, exactly as an
  absent ``derived_daily`` row is absent — "no data", not "a clean day".

Every consequence of that falls out of code that already exists, which is the reason it
is the right rule rather than merely a strict one:

* ``evaluate._daily`` counts a hit only for a day that is IN the series, so an unlogged
  day can never be a hit and can never extend a streak;
* ``series.recent_window`` reports how many days it actually measured, so an owner who
  logs on fewer than ``MIN_COMPARISON_DAYS`` of the trailing week gets ``thin_baseline``
  from ``bounds.calibrate`` and the metric is offered to the model as UNAVAILABLE;
* an owner who logs every day and never drinks late gets a baseline of ``0.0``, which
  ``bounds`` already refuses as ``no_baseline_signal`` — correctly, because there is
  nothing left to cut.

## Why a window is DAILY-only

``cadences`` is ``{"daily"}`` and that is the same mechanism #67 used to make a weekly
``sri`` unrepresentable rather than merely unreached. A ``weekly``/``total`` rule SUMS
its days (``evaluate._period_total``), and a sum cannot tell an unmeasured day from a
zero one: seven days of silence would total 0 and a cumulative cap would report the
window kept. The daily shape is the only one with a per-day slot where "we did not see
that day" survives to the score, so it is the only one a window may take.

## What the corpus does and does not supply

[[caffeine_sleep]] (Established) and [[alcohol_sleep]] (Established) evidence the TIMING
claim directly — caffeine at bedtime, 3 h *or 6 h* before bed measurably cuts total
sleep time (Drake 2013); alcohol before bed fragments the second half of the night
(Ebrahim 2013) and lowers HRV during sleep dose-dependently (Pietilä 2018: RMSSD
−2.0 / −5.7 / −12.9 ms at low / moderate / high dose). That is what ``targets.py``
already records as the reason neither substance has a daily-TOTAL target: the notes are
about dose **and timing**, not a daily total.

What they do NOT supply is a NUMBER: no safe late dose, and explicitly no universal
cutoff HOUR — [[caffeine_sleep]]'s own honesty policy is to "surface the metabolic-
variability confound (CYP1A2 half-life 3–7 h) rather than asserting a universal cutoff
hour", and [[caffeine_alcohol_cutoff_plan]] says a cutoff is the owner's *observed*
threshold, never a metabolic floor. So a windowed metric gets no ``EVIDENCE_TARGET`` and
no ``MEANINGFUL_STEP``, and ``levers`` puts it on the menu ONLY when the owner's own
FDR-controlled finding names that exact window. Choosing an hour for somebody whose data
has not chosen one would be inventing the very number the corpus refuses to state.
"""

from __future__ import annotations

from dataclasses import dataclass

from healthee.analytics.cutoffs import CUTOFF_HOURS, SUBSTANCE_CONFIG

# The hours a window may open at and the substances it may open on — the cutoff finder's
# own vocabulary (see the module docstring). A window at an hour the finder cannot test
# could never be justified by a finding, and one on a substance it does not analyse could
# never be linked to one.
WINDOW_HOURS: tuple[int, ...] = CUTOFF_HOURS
WINDOW_SUBSTANCES: frozenset[str] = frozenset(SUBSTANCE_CONFIG)


@dataclass(frozen=True)
class WindowedManualEntrySource:
    """Daily sum of one self-logged kind, restricted to entries at/after ``after_hour``.

    Deliberately NOT a subclass of :class:`~healthee.challenges.metrics.ManualEntrySource`
    even though it reads the same table with the same unit rule. The two differ on the
    one thing that matters — what an absent row means (module docstring) — and a subclass
    would be silently swept up by every ``isinstance(source, ManualEntrySource)`` dispatch
    in the tree, inheriting the zero-fill this type exists to refuse. As a separate member
    of the ``MetricSource`` union it is the type checker that forces each dispatch to
    decide.

    ``after_hour`` is an hour-of-day in the OWNER's zone, and the comparison is
    ``>=`` — an entry at exactly HH:00 is INSIDE the window. That is the same boundary
    ``analytics.cutoffs._classify_nights`` draws (``hour_local >= cutoff_h``, where
    ``hour_local`` carries the minutes), so the challenge and the finding that motivated
    it cannot disagree about which coffee counted.
    """

    kind: str
    unit: str
    after_hour: int


def metric_key(kind: str, hour: int) -> str:
    """The registry key for a window — byte-identical to the finder's ``metric_a``.

    ``analytics.cutoffs._cutoff_finding`` writes ``f"{substance}_after_{h:02d}"``. The
    equality is the whole linkage: ``lever_findings`` asks whether a finding names THIS
    window by comparing the two strings, and a challenge is offered on a window only
    when one does.
    """
    return f"{kind}_after_{hour:02d}"


def metric_label(base_label: str, hour: int) -> str:
    """The human label — the base metric's, qualified by the clock it is scored on."""
    return f"{base_label} after {hour:02d}:00"


def evidence_notes(kind: str) -> list[str]:
    """The corpus notes that evidence this substance's timing effect on sleep.

    The finder's own ``note_ids`` (``SUBSTANCE_CONFIG``), so the notes a windowed
    challenge is expected to cite are the same ones the finding it came from cites.
    """
    return list(SUBSTANCE_CONFIG[kind]["note_ids"])
