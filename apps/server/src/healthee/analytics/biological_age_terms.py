"""The biological-age payload's DISCLOSURE vocabulary — withheld · excluded · caveats.

Split out of ``analytics/biological_age.py`` in #117, which owns the maths. This module
owns what the number says about itself, and the two have genuinely different reasons to
change: the conversion moves when a published constant does, these sentences move when
what we can honestly claim does. (The split was also forced: the fitness caveat now
depends on WHICH instrument measured the VO₂max, and the file was at the 400-line gate.)

The three states are not interchangeable, and the note says so
([[biological_age_estimate]]):

    ``withheld``  you could have this; here is the action
    ``excluded``  nobody can price this, ever
    ``caveats``   this IS in your number, and here is which way it leans

A fourth was NOT invented for the instrument behind the fitness term. Naming the
instrument is a caveat — it is in the number and it tilts it — so it goes there, and the
entry SWAPS with the instrument rather than accumulating. That matters for correctness,
not tidiness: the self-reported-activity caveat is simply FALSE about a number measured
from a run, and shipping it anyway would tell an owner their measured fitness rests on a
questionnaire they never answered.
"""

from __future__ import annotations

from dataclasses import dataclass

from healthee.analytics.reference_scales import (
    ANCHOR_CAVEATS,
    SLEEP_DURATION_SELF_REPORT_SCALE,
    VO2MAX_REFERENCE_CLINICAL_COHORT,
)
from healthee.derive.freshness import NO_NIGHTS_IN_WINDOW, NOT_DERIVED_YET
from healthee.derive.srpa import SRPA_SELF_REPORT_CAVEAT
from healthee.derive.vo2max import METHOD_JURCA
from healthee.derive.vo2max_reserve import METHOD_RESERVE
from healthee.derive.vo2max_submax import METHOD_GRADED

# The terms of [[biological_age_estimate]]'s table. The composite is defined over all of
# them, so it cannot be computed without all of them.
FITNESS_TERM = "fitness"
SLEEP_DURATION_TERM = "sleep duration"

# Not a term — the lever this estimate deliberately does not price, stated in the payload
# so "biological age" cannot quietly change meaning between releases (#86).
REGULARITY_TERM = "regularity"
SRI_HAZARD_NOT_TRANSPORTABLE = "sri_hazard_not_transportable"
EXCLUDED_TERMS = [
    {
        "term": REGULARITY_TERM,
        "reason": SRI_HAZARD_NOT_TRANSPORTABLE,
        "message": (
            "Sleep regularity is not one of the levers behind this number. Scored on the "
            "same 70,000 people, the two standard Sleep Regularity Index calculators put "
            "only two in five into the same fifth of the population, and one found a "
            "mortality association where the other found none — so the published "
            "risk-per-SRI-point belongs to the software, not to the index. Yours is "
            "measured a third way again. You still get your regularity score and its "
            "one-hour-band target on the sleep page; what we cannot honestly do is "
            "convert it into years."
        ),
    }
]

# What the fitness term's OWN VO₂max rests on, per instrument (#117). One of these ships
# with every biological age, and only one — they are alternatives, not a list.
VO2MAX_MEASURED_FROM_SESSION = "vo2max_measured_from_session"
VO2MAX_MEASURED_FROM_RESERVE = "vo2max_measured_from_reserve_inversion"

_MEASURED_HORIZON_SENTENCE = (
    " We stop using a session after two weeks, because fitness lost to a break in "
    "training starts to show at about that point — after which this falls back to the "
    "no-exercise model and the number may step as the instrument changes, not as you do."
)

_METHOD_CAVEATS = {
    METHOD_GRADED: {
        "reason": VO2MAX_MEASURED_FROM_SESSION,
        "message": (
            "The fitness half of this number was measured rather than modelled: it comes "
            "from how your heart rate tracked your workload across a recorded session in "
            "the last two weeks. That is the most direct reading we can take without a "
            "laboratory, and it is still an estimate — checked against lab tests it is "
            "off by about 7% on average." + _MEASURED_HORIZON_SENTENCE
        ),
    },
    METHOD_RESERVE: {
        "reason": VO2MAX_MEASURED_FROM_RESERVE,
        "message": (
            "The fitness half of this number was measured from a recorded RUN, from how "
            "far into your heart-rate range you were — using a relationship measured "
            "across populations rather than one measured on you. The published bias in "
            "that relationship under-states fitness, so this reads conservative: if it is "
            "wrong, it is most likely making you look slightly older than you "
            "are." + _MEASURED_HORIZON_SENTENCE
        ),
    },
    # The Jurca model's footing is its self-reported activity input, and that sentence
    # lives with the coefficients it prices (``derive/srpa.py``, #108).
    METHOD_JURCA: SRPA_SELF_REPORT_CAVEAT,
}


def caveat_terms(fitness_method: str | None) -> list[dict]:
    """The ``caveats`` block: one entry per priced term, plus the fitness INSTRUMENT.

    ``fitness_method is None`` means the fitness term is absent altogether, and the Jurca
    footing is used — not because the number came from there (there is no number) but
    because the fallback tier is what the owner would get, and its unanswered question is
    the actionable thing to be told about.
    """
    return [
        {"term": FITNESS_TERM, **ANCHOR_CAVEATS[VO2MAX_REFERENCE_CLINICAL_COHORT]},
        {"term": FITNESS_TERM, **_METHOD_CAVEATS[fitness_method or METHOD_JURCA]},
        {"term": SLEEP_DURATION_TERM, **ANCHOR_CAVEATS[SLEEP_DURATION_SELF_REPORT_SCALE]},
    ]


# Why the whole estimate goes with any absent term, in the second person. The per-term
# reason and its "here is what we'd need" message are the INPUT metric's own, reused
# verbatim from ``derive/vo2max.WITHHOLD_MESSAGES``, so two surfaces cannot explain the
# same absence differently.
REQUIRED_TERMS_MESSAGE = (
    "Biological age is your chronological age plus each term's year contribution, so a "
    "term with no current value is not left out — it would silently assert you sit exactly "
    "at the reference for that lever. There is no biological age to report without all of "
    "them. The terms below are the ones that are current."
)

# The 14-night average TST has one way to be absent: nothing recorded in the window. It
# is a WINDOWED aggregate, so it cannot go stale the way a single latest row can — the
# query is already anchored to the owner's today. It can still be MISSING, and missing is
# the same assertion (``HR = 1.0``, i.e. 7 h/night) that staleness was.
SLEEP_DURATION_MESSAGES = {
    NO_NIGHTS_IN_WINDOW: (
        "No sleep has been recorded in the last 14 nights, so there is no nightly average "
        "to work from — wear the strap overnight and this comes back."
    )
}


@dataclass(frozen=True)
class Absent:
    """A required term the owner has no CURRENT input for, and why.

    ``reason`` is the input metric's own machine-readable id and ``message`` its own
    second-person "here is what we'd need" — never re-worded here, so this number and the
    input's own card explain one absence with one sentence.
    """

    term: str
    reason: str
    message: str


def absent(term: str, reason: str | None, messages: dict[str, str]) -> Absent:
    """One absent term. ``reason is None`` cannot happen for an absent term (the freshness
    rule always names one), so the fallback is defensive rather than a second meaning."""
    named = reason or NOT_DERIVED_YET
    return Absent(term, named, messages[named])
