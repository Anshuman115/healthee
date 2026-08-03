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

## Adding a metric here

Register an :class:`_Instruments` for it. ``flags->>'method'`` is a generic column that
``context._recent_daily`` already selects, so a metric whose derive layer stamps
``flags.method`` needs nothing but an entry. What it does NOT get is a default invented
here: the ``method_of`` callable belongs to the module that owns the metric, because "what
was a row with no stamp produced by" is a fact about that metric's history.
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
