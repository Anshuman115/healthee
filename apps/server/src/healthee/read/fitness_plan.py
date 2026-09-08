"""The VO2max-raising weekly Rx and its 12-week projected trajectory.

Its own module rather than a function inside ``read/fitness.py`` for the reason standards
section 1 gives — a file has one reason to change — and following that file's own
precedent: ``vo2max_payload`` and ``acwr`` each moved out when their argument outgrew a
file about four other metrics. This one's reason to change is the **trainability**
literature (how much VO2max a 12-week block typically buys, and what may be said about
it), which moves independently of training load, MVPA and strength.

Every constant below is [[vo2max]]'s, quoted from the note rather than chosen here. That
is the whole point of the split: the numbers and the sentences that license them sit
together, where an auditor reading one cannot miss the other.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from healthee.core.tenancy import reference_day
from healthee.derive._common import Cur
from healthee.derive.freshness import NO_AGE_MEDIAN, withheld_block
from healthee.read.mvpa_week import weekly_mvpa_rows

# ── The projection, and where every number in it comes from ──────────────────
#
# [[vo2max]] "Healthee implementation & honesty policy" specifies this formula in the
# corpus, in these words: the projection "scales with the gap to the age-median (low
# fitness = more trainable headroom), bounded **+2 to +5 mL/kg/min**:
# ``gain = clamp(0.4 × gap, 2, 5)`` — i.e. ~40% of the gap closed in a 12-week block".
#
# It also says why that sits where it does: Bacon 2013's meta-analysis (37 studies,
# n=334, 6-13 wk) found +0.51 L/min, about +6.4 ml/kg/min for an 80 kg adult, in YOUNG
# UNTRAINED people — "the upper end … we project ~half" — with Milanović 2015 for
# HIIT > MICT. The note's primary sources were read before these were named, because the
# cheap move would have been to delete the projection and call it honesty:
#
#   * The audit's charge is that the outer ``max(2.0, …)`` means the projection can never
#     say "no gain". That is true, and it is not a fabrication: the floor is a claim about
#     a TRAINING PROGRAM's typical effect, which the trainability literature supports
#     without reference to whether the trainee starts below their age median. The
#     ``0.4 × gap`` term is the headroom scaling on top of it, not the whole claim.
#   * What the note forbids is different and the code was guilty of it. D5, Established:
#     "**Never promise a specific VO₂max gain** — trainability is ~47% heritable and
#     ranges from near-zero to >1 L/min for the same program" [Bouchard 1999]. The note
#     licenses the number only "as an estimate of typical response, never a promise",
#     shown "if you follow the plan", with its citation and its bound.
#
# So the code yields to the note rather than the note to the code, and yields on the part
# the note actually governs: the constants are named and cited, the bound and the
# gap-fraction ship BESIDE the number so it reads as a range, and the conditional D5
# demands travels as a caveat instead of living in a docstring nobody on the wire can see.
_GAIN_GAP_FRACTION = 0.4
_GAIN_FLOOR_ML_KG_MIN = 2.0
_GAIN_CAP_ML_KG_MIN = 5.0
_PROJECTION_WEEKS = 12

# Where this block's trend lives on the SAME response, rather than a second copy of it.
# Dotted from the payload root, so a client resolves it without knowing this module.
_TREND_SOURCE = "vo2max.trend_90d"

# The weekly prescription. [[vo2max]] "The raising-VO₂max protocol (polarized)":
# "**Aerobic base** — ~3 sessions/week, 30-45 min easy/conversational (~60-70% HRmax,
# zone 2)". 3 × 30 is the LOW end of that band, which is the end a plan should be written
# at — a target the owner clears is a plan, one they cannot is a reproach.
_ZONE2_TARGET_MIN = 90

# The same protocol's second limb: "**One weekly high-intensity stimulus** — intervals
# (e.g. 4-5 × 1-4 min hard …) **or** VILPA". That band is 4 to 20 hard minutes a week and
# the note states no single figure, so 15 is a practitioner reading INSIDE it and is
# labelled as one here rather than dressed up as a published number. The upper anchor is
# real: Stamatakis 2022's VILPA cohort had a median 4.4 min/DAY (~31 min/week) at
# HR 0.62 for all-cause mortality [[mvpa_minutes_mortality]], so 15 is conservative
# against the observational evidence as well as against the interval band.
_VILPA_TARGET_MIN = 15

# D5's conditional, on the wire. Carries no date, unlike ``freshness.caveat_block``'s
# output: that block's ``as_of_date``/``age_days`` size a lean that a stale input put into
# a number, and this lean is structural — it is true of every projection on every day, and
# stamping today's date on it would invite a reader to think it might expire.
_PROJECTION_CAVEAT = {
    "reason": "typical_response_not_a_promise",
    "message": (
        "An estimate of the typical response to this plan over 12 weeks, if it is "
        "followed — not a promise. Trainability is about 47% heritable and the same "
        "program has produced anything from near-zero to a very large gain, so no "
        "specific gain can be promised to any one person."
    ),
    "note_id": "vo2max",
}

_NO_AGE_MEDIAN_MESSAGE = (
    "The 12-week projection scales with the gap between your estimate and the median "
    "for your age and sex, and we have no median for you — add your date of birth and "
    "sex in your profile and this comes back. The weekly plan below does not need it."
)


def projected_gain(current: float, median_for_age: float) -> float:
    """``clamp(0.4 × gap, 2, 5)`` — [[vo2max]]'s own formula, ported VERBATIM.

    ``gap`` is the deficit to the age-and-sex median, floored at zero: an owner at or
    above their median has no headroom term, and the floor below is then the whole claim.
    Known-value tested in ``tests/read/test_formulas.py``.
    """
    gap = max(0.0, median_for_age - current)
    return round(min(_GAIN_CAP_ML_KG_MIN, max(_GAIN_FLOOR_ML_KG_MIN, _GAIN_GAP_FRACTION * gap)), 1)


def fitness_plan_payload(
    cur: Cur, user_id: UUID, tz: str, day: date | None = None, *, vo2max: dict | None
) -> dict | None:
    """VO2max-raising weekly Rx + a 12-week projected trajectory (an estimate of
    typical response, bounded +2..+5 ml/kg/min, never a promise). [[vo2max]].

    Every input is the reference day's: the estimate it starts from, and the
    week-to-date it measures progress against.

    ## ``vo2max`` is REQUIRED, and that is the fix rather than a convenience

    It is the caller's already-built ``vo2max_payload`` block — the same one the
    response ships under its own key. This function used to call ``vo2max_payload``
    itself, so ``/api/activity`` built the identical block twice per request: 11 of its
    22 statements were exact repeats of another statement in the same request, and the
    96-point ``trend_90d`` travelled twice, byte for byte, at 12,466 of 22,401 bytes —
    55.6% of the payload (`PERF_AUDIT.md` B1/C1).

    Required, not defaulted, because a default would have been "fetch it yourself" and a
    caller that forgot would silently get the double read back (`HOW_WE_VERIFY.md`
    section 3: a required argument beats a remembered rule). ``None`` is a real value
    here — the owner has no VO2max estimate — not "not supplied".

    ## The projection is WITHHELD without an age median, never computed from a stand-in

    ``median_ref`` used to be ``float(vo.get("median_for_age") or 41)``. ``41`` cites
    nothing, and ``read/vo2max.py`` returns ``median_for_age: None`` deliberately — for an
    owner whose date of birth or sex was never recorded there is no age-and-sex reference
    distribution to price them against (#A2). The coalesce replaced that considered null
    with a constant and shipped it back out UNDER THE SAME KEY, so one response carried
    ``median_for_age: null`` in the ``vo2max`` block and ``median_for_age: 41.0`` in this
    one. That is A1's lesson one file across: the fix for a fabricated constant is not a
    better constant. The projection scales with the gap to the median, so with no median
    there is no gap and no projection — the three dependent fields go null behind a
    ``withheld`` block, and the weekly Rx, which needs no median, still ships.
    """
    as_of = reference_day(day, tz)
    vo = vo2max
    if not vo or vo.get("estimate") is None:
        return None
    cur_vo = float(vo["estimate"])
    raw_median = vo.get("median_for_age")
    median_ref = None if raw_median is None else float(raw_median)
    gain = None if median_ref is None else projected_gain(cur_vo, median_ref)
    week_mod, week_vig = _week_to_date_mvpa(cur, user_id, as_of)
    return {
        "current": round(cur_vo, 1),
        "projected_12wk": None if gain is None else round(cur_vo + gain, 1),
        "gain": gain,
        "median_for_age": None if median_ref is None else round(median_ref, 1),
        # The bound the number was produced INSIDE, always — so a reader sees a bounded
        # typical response rather than a forecast. These ship beside a null gain too: the
        # shape of the claim we would have made is not itself withheld, and a key that
        # appears only on the answered case is one a client learns to ignore
        # (``read/today_series.py``'s ``as_of_date``).
        "gain_floor": _GAIN_FLOOR_ML_KG_MIN,
        "gain_cap": _GAIN_CAP_ML_KG_MIN,
        "gain_gap_fraction": _GAIN_GAP_FRACTION,
        "weeks": _PROJECTION_WEEKS,
        # Never bare — [[vo2max]] D5. The conditional was in a docstring and nowhere a
        # reader of the payload could reach it.
        "caveats": [] if gain is None else [_PROJECTION_CAVEAT],
        "withheld": None
        if gain is not None
        else withheld_block(NO_AGE_MEDIAN, _NO_AGE_MEDIAN_MESSAGE, as_of, None),
        "plan": {
            "zone2_target_min": _ZONE2_TARGET_MIN,
            "zone2_done_min": None if week_mod is None else round(week_mod),
            "zone2_desc": "3 × 30 min easy aerobic — Zone 2, conversational pace",
            "vilpa_target_min": _VILPA_TARGET_MIN,
            "vilpa_done_min": None if week_vig is None else round(week_vig),
            "vilpa_desc": "1 hard session — 4-5 × 1-min brisk-to-hard bursts "
            "(stairs / hill / fast walk)",
        },
        # ``vo2max_training_program`` is an ALIAS of ``vo2max`` — see ``read/activity.py``.
        "note_id": "vo2max",
        # A POINTER, where a 96-point copy of `vo2max.trend_90d` used to be.
        #
        # The array is on this same response already, under the key this names, and it
        # was identical byte for byte — 6,233 bytes of the 22,401 `/api/activity` ships
        # (`PERF_AUDIT.md` B1). Deleting the key outright would leave a reader of this
        # block with no way to know the trend exists at all; naming where it lives costs
        # 34 bytes and says so. No client read this copy: the app parses the trend from
        # `vo2max.trend_90d` (`data/models/vo2max.dart`) and has no model for this block.
        "trend_source": _TREND_SOURCE,
    }


def _week_to_date_mvpa(cur: Cur, user_id: UUID, as_of: date) -> tuple[float | None, float | None]:
    """Moderate and vigorous minutes from this week's Monday through ``as_of``.

    A day whose ``mvpa_min`` row carries no intensity breakdown makes the week's
    done-minutes UNKNOWABLE rather than smaller — the same rule ``mvpa_week`` applies, and
    applied here rather than re-derived because progress against a plan is exactly where
    an understated total reads as "you have done less than you have".
    """
    monday = as_of - timedelta(days=as_of.weekday())
    week_mod: float | None = 0.0
    week_vig: float | None = 0.0
    for _d, mod, vig, _mv in weekly_mvpa_rows(cur, user_id, as_of, (as_of - monday).days + 1):
        if mod is None or vig is None:
            week_mod = week_vig = None
        elif week_mod is not None and week_vig is not None:
            week_mod, week_vig = week_mod + mod, week_vig + vig
    return week_mod, week_vig
