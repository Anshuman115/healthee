"""WHICH INSTRUMENT produced a number in the coach's compact metric pivot (#120).

## The defect

[[hr_reserve_vo2max]] Directive 4 is explicit: "Never average the two methods … **State
which one produced the value.**" #117 made the second half true on the wire —
``/api/today.vo2max`` carries ``method``, ``method_caveat``, ``see_source``,
``measured_as_of`` and ``n_sessions``, and ``biological_age.contributions[]`` carries
``method`` too.

It did not reach the coach. ``context._recent_daily`` handed the model
``vo2max_estimate`` as a **bare number**, so the coach could state a VO₂max without being
able to say whether it came from a measured run, a heart-rate-reserve inversion, or a
questionnaire — instruments carrying materially different error (MAPE 6.85 % vs a
modelled ±3.2 SD vs a 5.075 SEE) and materially different caveats.

That gap matters MORE here than on the payload. The payload is rendered by a UI we
control; the coach *writes sentences about the number*. An instrument-blind coach can say
"your fitness is measured at 39.6" about a value Jurca estimated — the exact conflation
#108 was about, re-entering through a different door.

## Why one suffixed word plus one legend line, and not the payload

The pivot sits inside EVERY prompt the product sends, and #105 established that prompt
size is the dominant cost driver: a coach question costs $0.179, ~86 % of it the evidence
block, and the 20-question cap exists because of that. So the instrument rides as a single
word appended to the value — measured at **exactly +1 cl100k token per tagged value** —
and the vocabulary is explained **once**, in a legend emitted only when the pivot actually
holds a tagged value.

Measured with ``tiktoken``/``cl100k_base`` over the real assembled coach prompt: **+88
input tokens** on a full 30-day window with a VO₂max on every day (58 legend + 30 × 1),
against the 80,435 tokens #105 measured per coach question — **+0.11 %**, ~$0.0002 per
question. A window with no VO₂max row costs **zero**: every other cell is byte-identical.

The legend is the load-bearing half, not decoration. A bare ``model`` tag reads as
approval; the sentence is what makes a Jurca-derived number impossible to describe in the
vocabulary of a measurement.

## The same vocabulary guards the AGGREGATES (#125)

#120 named the instrument on each per-day value and left the REDUCTIONS over those values
alone — ``context``'s ``## Today snapshot`` z-score, its ``## Trend summary`` 7-day mean
and its ``## Personal baselines`` 30-day median all collapsed whatever instruments the
window happened to hold into one number. A mean over two instruments **is** the blend D4
forbids, and #117 made it structurally impossible in ``derive/vo2max_tier.py`` only —
inside the tier, never over the days the tier wrote. On the owner's own pair (a graded
39.6 and a reserve 41.7, three days apart, inside all three windows) #117 measured the
blend at **40.7** against his single-instrument **40.6**: one tenth, invisible to
inspection. Correctness nobody can see by looking has to be structure, not care.

:class:`InstrumentGuard` is that structure. It answers ONE question — which instruments
does this metric's window actually hold — and the reductions ask it before reducing. A
window holding one instrument reduces as before and says whose number it is
(:meth:`InstrumentGuard.label`); a window holding two reduces to **nothing at all**, and
:meth:`InstrumentGuard.section` says so where the number used to be, because an omission
the model cannot tell from absent data is the #126 defect in a second place.

## Adding a metric here

Register an :class:`_Instruments` for it. ``flags->>'method'`` is a generic column that
``context._recent_daily`` already selects, so a metric whose derive layer stamps
``flags.method`` needs nothing but an entry. What it does NOT get is a default invented
here: the ``method_of`` callable belongs to the module that owns the metric, because "what
was a row with no stamp produced by" is a fact about that metric's history.

A metric that stamps its instrument under a DIFFERENT flag key is not registrable yet:
``steps_total`` and ``distance_m_daily`` name theirs in ``flags.source``
(``derive/device_totals.py``), and both the pivot's query and the guard's read
``flags->>'method'``. Generalising the key is a small change; whether those two metrics
SHOULD be guarded is not, and it is deliberately not decided here — see the report on #125.
"""

from __future__ import annotations

from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass

from healthee.derive.vo2max import METHOD_JURCA
from healthee.derive.vo2max_reserve import METHOD_RESERVE
from healthee.derive.vo2max_submax import METHOD_GRADED
from healthee.derive.vo2max_tier import method_of as vo2max_method_of


@dataclass(frozen=True)
class _Instruments:
    """One metric's instrument vocabulary for the pivot.

    ``method_of`` resolves a stored ``flags.method`` (possibly absent) to a canonical
    instrument id and is owned by the metric's own module — never re-implemented here.
    ``tags`` is the one word appended to the value; ``legend`` is what that word means,
    in the model's own reading order.
    """

    method_of: Callable[[object], str]
    tags: Mapping[str, str]
    legend: str


# VO₂max is one metric with three instruments in a fixed order (``derive/vo2max_tier.py``).
# The tags are deliberately not interchangeable words: `graded` and `reserve` are
# measurements of an effort the owner actually made, `model` is a questionnaire estimate of
# someone who did not exert at all, and no sentence may move a number between those two
# categories.
_VO2MAX = _Instruments(
    method_of=vo2max_method_of,
    tags={METHOD_GRADED: "graded", METHOD_RESERVE: "reserve", METHOD_JURCA: "model"},
    legend=(
        "VO2max carries its instrument: graded = measured on a recorded session; reserve = "
        "measured on a run, reads low; model = a Jurca questionnaire that measures no "
        "exertion. Never average them; name it for any VO2max you quote [hr_reserve_vo2max]."
    ),
)

_REGISTRY: Mapping[str, _Instruments] = {"vo2max_estimate": _VO2MAX}


def instrument_tag(metric: str, stored_method: object) -> str | None:
    """The one-word instrument for a stored row, or ``None`` when there is nothing to say.

    ``None`` for every unregistered metric — those cells stay byte-identical — and also for
    a registered metric whose stored method is one this module has no word for. That second
    case is silence on purpose: a future instrument nobody registered here must read as
    "unstated", never inherit another instrument's word.
    """
    spec = _REGISTRY.get(metric)
    if spec is None:
        return None
    return spec.tags.get(spec.method_of(stored_method))


def instrument_legends(tagged_metrics: Iterable[str]) -> list[str]:
    """The legend line for each metric that actually rendered a tag, in registry order.

    Keyed on tags RENDERED rather than metrics present, so a pivot that could not name an
    instrument does not ship a sentence explaining words it never wrote.
    """
    present = set(tagged_metrics)
    return [spec.legend for metric, spec in _REGISTRY.items() if metric in present]


def registered_metrics() -> tuple[str, ...]:
    """Every metric whose instrument this module can name — the guard's read list."""
    return tuple(_REGISTRY)


def _word(metric: str, instrument: str) -> str:
    """The one-word tag for a canonical instrument, or the instrument id when none exists.

    The id rather than silence, unlike :func:`instrument_tag`: this word is only ever
    rendered INSIDE a sentence that already says the window is mixed, where naming an
    unregistered instrument by its raw id is informative and cannot be mistaken for one of
    the vocabulary words. Appending an unknown word to a bare VALUE is the case that must
    stay silent, and that one still is.
    """
    return _REGISTRY[metric].tags.get(instrument, instrument)


# What the suppressed statistic is replaced BY. It has to name the metric, the instruments,
# the fact that nothing above reduced it, and why — an omission the model reads as "no data"
# is the honest-absence defect this whole change is about, one section over.
_MIXED_HEADING = "## Not reduced to one number — mixed instruments in the last {days} days"
_MIXED_LINE = (
    "- {metric}: {instruments}. No mean, median, z-score or anomaly for it appears anywhere "
    "above: a blend across instruments has no validation behind it and averaging them is "
    "forbidden [hr_reserve_vo2max]. Quote the tagged per-day values instead."
)


@dataclass(frozen=True)
class InstrumentGuard:
    """Which instruments each registered metric's window holds — asked before any reduction.

    Built once per context assembly over ONE window (``context._INSTRUMENT_WINDOW_DAYS``),
    because two windows would be two answers to "does this metric mix instruments" and the
    sections that ask could then disagree on the same page.
    """

    by_metric: Mapping[str, tuple[str, ...]]
    window_days: int

    def blocks(self, metric: str) -> bool:
        """May this metric NOT be collapsed into one statistic? True once two instruments
        are in the window — including one this module has no word for, which is a second
        instrument whether or not we can name it."""
        return len(self.by_metric.get(metric, ())) > 1

    def label(self, metric: str) -> str:
        """The metric's name in an aggregate row, suffixed with the instrument behind it.

        Unsuffixed for an unregistered metric, for a window with no rows, and for a blocked
        one (which renders no row at all) — so the suffix appears exactly where a single
        instrument produced every value that fed the number [[hr_reserve_vo2max]] D4.
        """
        found = self.by_metric.get(metric, ())
        if len(found) != 1:
            return metric
        return f"{metric} ({_word(metric, found[0])})"

    def section(self) -> str:
        """The block that stands where the blocked metrics' statistics would have been."""
        blocked = [m for m in self.by_metric if self.blocks(m)]
        if not blocked:
            return ""
        lines = [_MIXED_HEADING.format(days=self.window_days)]
        for metric in blocked:
            words = " + ".join(_word(metric, i) for i in self.by_metric[metric])
            lines.append(_MIXED_LINE.format(metric=metric, instruments=words))
        return "\n".join(lines)


def guard_from_rows(rows: Iterable[tuple[str, object]], window_days: int) -> InstrumentGuard:
    """Group ``(metric, stored flags.method)`` pairs into the instruments each metric holds.

    Pure, so the no-blending guarantee is testable without a database. Unregistered metrics
    are dropped: a metric this module cannot speak for is one the reductions must treat
    exactly as they did before, or the guard would silently suppress statistics on evidence
    it does not have.
    """
    found: dict[str, list[str]] = {}
    for metric, stored in rows:
        spec = _REGISTRY.get(metric)
        if spec is None:
            continue
        canonical = spec.method_of(stored)
        bucket = found.setdefault(metric, [])
        if canonical not in bucket:
            bucket.append(canonical)
    return InstrumentGuard(
        {m: tuple(sorted(v, key=lambda i: _order(m, i))) for m, v in found.items()}, window_days
    )


def _order(metric: str, instrument: str) -> tuple[int, str]:
    """Registry (i.e. precedence) order, unregistered instruments last and alphabetical.

    Deterministic output matters here beyond tidiness: the assembled context is what the
    per-day cache keys and the token budgets are measured against.
    """
    tags = list(_REGISTRY[metric].tags)
    return (tags.index(instrument), "") if instrument in tags else (len(tags), instrument)
