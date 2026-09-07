"""The acute:chronic workload ratio — a descriptive load-spike signal, and only that.

Its own module rather than a function inside ``read/fitness.py`` for the reason standards
section 1 gives: a file has one reason to change, and this one's reason is a **Contested**
note whose evidence is still moving (a 2025 meta-analysis, a 2025 running cohort that
found weekly ratios *inversely* associated with injury). Training load, strain and MVPA do
not move when that evidence does. The split also keeps the argument below beside the code
it governs instead of buried in a file about four other metrics.

``acwr`` is computed from ``cardio_load``'s own trend, so it inherits that block's window
and cannot see past it — it takes the payload, never the database.
"""

from __future__ import annotations

# ACWR's chronic window, in days of history, below which the ratio is SUPPRESSED.
#
# [[training_load_acwr]] Directive 6, graded Established: "Suppress all ACWR output when
# chronic history < 28 days or chronic load ≈ 0 (ratio unstable/undefined)". The note's
# Safety bounds repeat it, and its own "Healthee implementation" section already asserted
# the product did this — while the code's only floor was seven rows. See :func:`acwr`.
_ACWR_MIN_CHRONIC_DAYS = 28
_ACWR_ACUTE_DAYS = 7


def acwr(cardio: dict | None) -> dict | None:
    """Acute:chronic workload ratio — a DESCRIPTIVE load-spike signal, never a verdict.
    [[training_load_acwr]].

    ## The corpus was right and this function was wrong; it is the code that changed

    ``packages/knowledge/sports-science/metrics/training-load-acwr.md`` is graded
    **Contested** and says in its summary line that ACWR is "a useful descriptive signal
    for spotting load spikes — **never a verdict**", that the 0.8-1.3 / 1.5 cut-points are
    "soft heuristics, not guardrails", and that what must not ship is "the ratio's
    discredited numeric verdict". This function shipped exactly that verdict, as a bare
    categorical ``state`` string, from as few as seven rows, citing a different note.

    The note's primary sources were checked before changing anything, because the corpus is
    the product's spine and the cheap fix would have been to soften the note. They hold:

    * **Dalen-Lorentsen 2021 (BJSM)** — the only randomised trial, 482 elite youth
      footballers, a full season managed by published ACWR principles, **no fewer injuries
      or illnesses than control**. This is the source that settles it: a metric whose one
      interventional test is null cannot license a categorical judgement about a person.
    * **Impellizzeri 2020 (IJSPP)** — ACWR magnifies acute load *without adding predictive
      value beyond acute load alone*, and discretising it into bands invites false
      precision. **Impellizzeri 2019** further shows the reproduced "sweet-spot" figure is
      schematic rather than data-derived, so ``"optimal"`` names a band from a drawing.
    * **Lolli 2019 (BJSM)** — the acute window is a subset of the chronic one, so numerator
      and denominator are mathematically coupled and correlate with injury spuriously.
    * **Wang 2020 (Sports Medicine)** — modelled continuously and with outliers handled,
      the association weakens or disappears.

    So ``state`` is DELETED rather than reworded. A descriptive "above/below your usual
    load" cue was the alternative offered, and it is not taken here: it would still be a
    categorical read off the same uncited cut-points, and the ratio with its two terms
    already says "above" or "below" without a label claiming to know what that means.

    ## The suppression the note already claimed we had

    D6, graded **Established**: "Suppress all ACWR output when chronic history < 28 days or
    chronic load ≈ 0 (ratio unstable/undefined)" — a small denominator manufactures
    alarming ratios for new and returning users. The note's own *Healthee implementation*
    section asserted in prose that this product does exactly that. It did not: the only
    floor was seven rows, and with exactly seven ``vals[-7:]`` and ``vals[-28:]`` are the
    same values, so ``ratio`` was 1.0 by construction and "optimal" was published from one
    week with no history to compare it against. A false claim about the product inside the
    knowledge base is the failure ``docs/ENGINEERING_STANDARDS.md`` section 4 calls the
    worst kind, and the fix it prescribes is to make the code true, not the note weaker.

    ``vals`` are ROWS, not days — ``derived_daily`` holds a ``cardio_load`` row only for
    days it could compute one. The calendar span is bounded by the caller's window
    (``_LOAD_WINDOW_DAYS`` = 30), so 28 rows sit inside 30 days and the gap a wear break
    can open is at most two; ``n_chronic`` and ``n_acute`` ship so a reader never has to
    take that on trust.
    """
    vals = [
        float(t["value"]) for t in (cardio or {}).get("trend_30d", []) if t.get("value") is not None
    ]
    if len(vals) < _ACWR_MIN_CHRONIC_DAYS:
        return None
    acute_vals = vals[-_ACWR_ACUTE_DAYS:]
    chronic_vals = vals[-_ACWR_MIN_CHRONIC_DAYS:]
    acute = sum(acute_vals) / len(acute_vals)
    chronic = sum(chronic_vals) / len(chronic_vals)
    # The note's other suppression limb, "chronic load ≈ 0". No epsilon is invented for
    # "≈": TRIMP is non-negative, so a chronic mean of zero is the whole degenerate case
    # the note names, and a threshold above it would be a number with nothing behind it.
    if chronic <= 0:
        return None
    return {
        "ratio": round(acute / chronic, 2),
        "acute_7d": round(acute, 1),
        "chronic_28d": round(chronic, 1),
        # The window each term MEANT and the count it GOT — the shape
        # ``derive/sleep_score.py`` stores on every sleep-debt row.
        "n_acute": len(acute_vals),
        "n_chronic": len(chronic_vals),
        # The note that licenses THIS number, and grades it Contested. It cited
        # ``training_stress_score`` — a different, Probable-graded note about TRIMP — so
        # ``training_load_acwr`` appeared nowhere on this wire and the explainer sheet for
        # the ratio would have opened blank.
        "research_notes": ["training_load_acwr"],
    }
