"""The arithmetic — intervals, not point estimates, and a paired test with a p value.

This module is the reason the harness can be believed. Every rate it produces carries a
95% Wilson interval, and a comparison between two arms is a PAIRED test (McNemar, exact
binomial on the discordant pairs) rather than two independent proportions: the arms ran
the same questions, and pairing is what makes a small n say anything at all.

Wilson rather than the textbook normal interval because n here is tens, not thousands,
and the rates sit near the ends — the normal interval famously produces (1.0, 1.0) for
8/8 and can run below zero, which would let the harness claim certainty it has not
earned. Student's t rather than z for the token means for the same reason.

It is pure arithmetic over records: no network, no database, no model. That is why its
unit tests DO run in the normal suite while the harness itself never does.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass

from scipy.stats import binomtest, t
from tests.grounding_eval.records import ERROR, RunRecord

Z95 = 1.959963984540054


def wilson(successes: int, n: int, z: float = Z95) -> tuple[float, float]:
    """The Wilson score interval for ``successes``/``n`` — (lo, hi), clamped to [0, 1].

    ``n == 0`` returns the whole interval: with no observations every rate is possible,
    which is the honest statement and not an error.
    """
    if n <= 0:
        return (0.0, 1.0)
    p = successes / n
    denom = 1.0 + z * z / n
    centre = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return (max(0.0, centre - half), min(1.0, centre + half))


@dataclass(frozen=True)
class Rate:
    """A proportion that can never be quoted without its n and its interval."""

    label: str
    successes: int
    n: int

    @property
    def rate(self) -> float:
        return self.successes / self.n if self.n else 0.0

    @property
    def ci(self) -> tuple[float, float]:
        return wilson(self.successes, self.n)

    def line(self) -> str:
        lo, hi = self.ci
        return (
            f"{self.label:<18} {self.successes:>3}/{self.n:<3} = {self.rate:5.1%}  "
            f"[95% CI {lo:5.1%} – {hi:5.1%}]"
        )


def mean_ci(values: Sequence[float]) -> tuple[float, float, float]:
    """(mean, lo, hi) at 95% using Student's t — (0,0,0) for an empty sample.

    A single observation has a mean and no interval, so it reports (v, v, v): pretending
    otherwise would put an interval on a number that has none.
    """
    n = len(values)
    if n == 0:
        return (0.0, 0.0, 0.0)
    mean = sum(values) / n
    if n == 1:
        return (mean, mean, mean)
    sd = math.sqrt(sum((v - mean) ** 2 for v in values) / (n - 1))
    half = float(t.ppf(0.975, n - 1)) * sd / math.sqrt(n)
    return (mean, mean - half, mean + half)


@dataclass(frozen=True)
class Paired:
    """The McNemar table for two arms over the same questions, plus its exact p.

    ``b`` = pairs the FIRST arm shipped and the second did not; ``c`` = the reverse.
    Concordant pairs carry no information about a difference and are counted only so the
    reader can see how much of the sample the test actually rests on.
    """

    pairs: int
    both: int
    neither: int
    b_only: int
    c_only: int
    p_value: float

    @property
    def significant(self) -> bool:
        return self.p_value < 0.05

    @property
    def verdict(self) -> str:
        if self.b_only == self.c_only:
            return "no difference at all in the paired outcomes"
        direction = "WORSE" if self.b_only > self.c_only else "BETTER"
        if not self.significant:
            return (
                f"{direction} on {abs(self.b_only - self.c_only)} net pair(s), "
                f"NOT significant at 95% (p={self.p_value:.3f}) — this is 'not measurably "
                "different', not 'the same'"
            )
        return f"{direction}, significant at 95% (p={self.p_value:.3f})"


def mcnemar(b_only: int, c_only: int) -> float:
    """Two-sided exact p for a McNemar table's discordant pairs.

    Exact binomial rather than the chi-square approximation: with a handful of discordant
    pairs the approximation is anti-conservative, and this harness exists precisely to
    stop small samples from sounding confident. No discordance at all ⇒ p = 1.0.
    """
    n = b_only + c_only
    if n == 0:
        return 1.0
    return float(binomtest(b_only, n, 0.5).pvalue)


def paired(first: Sequence[RunRecord], second: Sequence[RunRecord]) -> Paired:
    """Pair two arms on (question, repeat) and run McNemar over the shared pairs.

    Pairing on the repeat INDEX is not pairing on identical conditions — the model is
    stochastic and repeat 2 of an arm is not "the same trial" as repeat 2 of the other.
    What pairing buys is removal of the between-QUESTION variance, which dominates here
    (one question ships 8/8, another 1/8). Records present in only one arm are dropped.
    """
    left = {(r.question_id, r.repeat): r.success for r in scored(first)}
    right = {(r.question_id, r.repeat): r.success for r in scored(second)}
    shared = sorted(set(left) & set(right))
    both = sum(1 for k in shared if left[k] and right[k])
    neither = sum(1 for k in shared if not left[k] and not right[k])
    b_only = sum(1 for k in shared if left[k] and not right[k])
    c_only = sum(1 for k in shared if not left[k] and right[k])
    return Paired(
        pairs=len(shared),
        both=both,
        neither=neither,
        b_only=b_only,
        c_only=c_only,
        p_value=mcnemar(b_only, c_only),
    )


def scored(records: Sequence[RunRecord]) -> list[RunRecord]:
    """Every record a rate may rest on — i.e. everything except transport/DB errors.

    An error is excluded from the DENOMINATOR rather than counted as a failure: a
    connection reset is not evidence about grounding, and folding it in would move the
    exact number this harness exists to protect. The count is reported separately, so an
    arm that errored half its questions cannot look like a clean small sample.
    """
    return [r for r in records if r.outcome != ERROR]


def answering(records: Sequence[RunRecord]) -> list[RunRecord]:
    """Only the scored records whose question expects an ANSWER — not the refusal floor."""
    return [r for r in scored(records) if r.expect == "answer"]


def errors(records: Sequence[RunRecord]) -> list[RunRecord]:
    return [r for r in records if r.outcome == ERROR]


def ship_rate(records: Sequence[RunRecord], label: str = "overall") -> Rate:
    """The headline: of the answers we paid for, how many reached the owner."""
    answers = answering(records)
    return Rate(label, sum(1 for r in answers if r.success), len(answers))


def rates_by_kind(records: Sequence[RunRecord]) -> list[Rate]:
    """Success rate per question kind — the safety floor included, labelled by its kind."""
    kinds = sorted({r.kind for r in records})
    out: list[Rate] = []
    for kind in kinds:
        subset = [r for r in scored(records) if r.kind == kind]
        out.append(Rate(kind, sum(1 for r in subset if r.success), len(subset)))
    return out


def rates_by_question(records: Sequence[RunRecord]) -> list[Rate]:
    """Per-question success — where a single bad surface hides inside a decent average."""
    rows = scored(records)
    ids = sorted({r.question_id for r in rows})
    return [
        Rate(qid, sum(1 for r in rows if r.question_id == qid and r.success), c)
        for qid in ids
        if (c := sum(1 for r in rows if r.question_id == qid))
    ]
