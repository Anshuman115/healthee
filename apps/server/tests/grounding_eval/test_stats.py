"""The eval's arithmetic, pinned to known values — no network, no DB, no model.

These DO run in the normal suite while the harness itself never does, and that split is
deliberate: the harness's whole value is that its numbers can be trusted, so an interval
that is silently wrong is worse than no interval at all. Every expected value below is
either hand-computable or a published textbook case.
"""

from __future__ import annotations

from tests.grounding_eval import stats
from tests.grounding_eval.records import ERROR, FALLBACK, GROUNDED, REFUSED, RunRecord


def _record(
    qid: str = "q",
    repeat: int = 0,
    *,
    success: bool = True,
    outcome: str = GROUNDED,
    kind: str = "knowledge",
    expect: str = "answer",
    prompt_tokens: int = 0,
    warnings: list[str] | None = None,
) -> RunRecord:
    return RunRecord(
        question_id=qid,
        kind=kind,
        surface="coach",
        repeat=repeat,
        outcome=outcome,
        success=success,
        expect=expect,
        prompt_tokens=prompt_tokens,
        warnings=list(warnings or []),
    )


# ── failure causes ───────────────────────────────────────────────────────────
# The census that turns "a third never shipped" into "a third never shipped BECAUSE".
# #99's diagnosis had to be grepped out of a console log; these pin the parse so the
# next arm carries its own causes.

_FALLBACK_LOG = (
    'coach: candidate failed the gates twice (("Probable claim stated without a hedge: '
    "'You should probably rest today.'\", \"Interpretive sentence lacks a citation: "
    "'Your data shows a problem.'\")) — honest fallback"
)
_GUARD_LOG = (
    "OUTPUT GUARDRAIL fired: rule=personal_death_risk_number — answer blocked, not shipped."
)


def test_failure_causes_group_by_cause_not_by_sentence() -> None:
    """One defect over many sentences must read as one row, which is the whole finding."""
    records = [_record(warnings=[_FALLBACK_LOG]) for _ in range(3)]
    assert stats.failure_causes(records) == [
        ("Interpretive sentence lacks a citation", 3),
        ("Probable claim stated without a hedge", 3),
    ]


def test_a_guardrail_fire_is_its_own_cause() -> None:
    assert stats.failure_causes([_record(warnings=[_GUARD_LOG])]) == [("hard output guardrail", 1)]


def test_the_log_lines_own_surface_label_is_not_a_cause() -> None:
    """'coach:' and 'grounded_ask:' prefix every line; counting them would be noise."""
    causes = dict(stats.failure_causes([_record(warnings=[_FALLBACK_LOG])]))
    assert "coach" not in causes and "grounded_ask" not in causes


def test_unrelated_warnings_contribute_no_causes() -> None:
    noise = _record(warnings=["coach repeated tool call: query_metric"])
    assert stats.failure_causes([noise]) == []


# ── Wilson ───────────────────────────────────────────────────────────────────


def test_wilson_matches_the_published_interval() -> None:
    """8/10 at 95%: the published Wilson interval is (0.490, 0.943)."""
    lo, hi = stats.wilson(8, 10)
    assert round(lo, 3) == 0.490
    assert round(hi, 3) == 0.943


def test_wilson_solves_its_own_defining_equation() -> None:
    """The closed form, checked against a NUMERICAL root of the score equation.

    A remembered constant can be misremembered — this derives the same endpoints a
    second way. Wilson's interval is by definition the set of p where the score
    statistic |p̂ − p| / sqrt(p(1−p)/n) is within z, so its endpoints are the roots of
    ``(p̂ − p)² − z²·p(1−p)/n``. If the algebra above were mistyped, these disagree.
    """
    for successes, n in ((8, 10), (1, 11), (34, 59), (0, 6)):
        p_hat = successes / n

        def score(p: float, p_hat: float = p_hat, n: int = n) -> float:
            return (p_hat - p) ** 2 - stats.Z95**2 * p * (1 - p) / n

        lo, hi = stats.wilson(successes, n)
        assert abs(score(lo)) < 1e-12, (successes, n, lo)
        assert abs(score(hi)) < 1e-12, (successes, n, hi)


def test_wilson_never_claims_certainty_from_a_perfect_small_sample() -> None:
    """8/8 is not proof of 100% — the normal interval would say (1.0, 1.0) and lie."""
    lo, hi = stats.wilson(8, 8)
    assert lo < 0.7
    assert hi == 1.0


def test_wilson_stays_inside_zero_and_one_at_the_ends() -> None:
    assert stats.wilson(0, 5) == (0.0, stats.wilson(0, 5)[1])
    assert stats.wilson(0, 5)[1] < 0.53
    assert stats.wilson(5, 5)[1] == 1.0


def test_wilson_with_no_observations_is_the_whole_interval() -> None:
    """No data ⇒ every rate is possible. That is the honest statement, not an error."""
    assert stats.wilson(0, 0) == (0.0, 1.0)


def test_a_bigger_sample_narrows_the_interval() -> None:
    narrow = stats.wilson(80, 100)
    wide = stats.wilson(8, 10)
    assert (narrow[1] - narrow[0]) < (wide[1] - wide[0])


# ── McNemar ──────────────────────────────────────────────────────────────────


def test_mcnemar_with_no_discordant_pairs_is_p_one() -> None:
    assert stats.mcnemar(0, 0) == 1.0


def test_mcnemar_needs_more_than_a_handful_of_pairs_to_be_significant() -> None:
    """4-vs-0 is p=0.125 — a clean direction that is still not evidence at 95%."""
    assert round(stats.mcnemar(0, 4), 3) == 0.125
    assert stats.mcnemar(0, 4) >= 0.05


def test_mcnemar_becomes_significant_once_the_discordance_is_large_enough() -> None:
    """0-vs-6 is p=0.031 — the exact binomial, not the chi-square approximation."""
    assert round(stats.mcnemar(0, 6), 3) == 0.031
    assert stats.mcnemar(0, 6) < 0.05


def test_mcnemar_is_symmetric_in_direction() -> None:
    assert stats.mcnemar(2, 7) == stats.mcnemar(7, 2)


# ── pairing ──────────────────────────────────────────────────────────────────


def test_pairing_matches_on_question_and_repeat_and_drops_the_unmatched() -> None:
    before = [_record("a", 0), _record("b", 0, success=False), _record("only_here", 0)]
    after = [_record("a", 0, success=False), _record("b", 0)]
    test = stats.paired(before, after)
    assert test.pairs == 2  # "only_here" has no partner and is dropped
    assert (test.b_only, test.c_only) == (1, 1)
    assert test.p_value == 1.0


def test_a_clean_improvement_reads_as_better_and_names_its_significance() -> None:
    before = [_record(f"q{i}", 0, success=False) for i in range(6)]
    after = [_record(f"q{i}", 0) for i in range(6)]
    test = stats.paired(before, after)
    assert (test.b_only, test.c_only) == (0, 6)
    assert test.significant
    assert "BETTER" in test.verdict


def test_an_unproven_difference_says_so_in_words() -> None:
    """The failure mode this harness exists to prevent: 'not worse' read as 'the same'."""
    before = [_record(f"q{i}", 0, success=False) for i in range(3)]
    after = [_record(f"q{i}", 0) for i in range(3)]
    verdict = stats.paired(before, after).verdict
    assert "NOT significant" in verdict
    assert "not 'the same'" in verdict


# ── what counts, and what must not ───────────────────────────────────────────


def test_errors_are_excluded_from_the_denominator_not_counted_as_failures() -> None:
    records = [
        _record("a", 0),
        _record("b", 0, success=False, outcome=ERROR),
        _record("c", 0, success=False, outcome=FALLBACK),
    ]
    rate = stats.ship_rate(records)
    assert (rate.successes, rate.n) == (1, 2)
    assert len(stats.errors(records)) == 1


def test_the_refusal_floor_is_never_pooled_into_the_ship_rate() -> None:
    """A safety refusal is a floor, not a quality rate — pooling them flatters both."""
    records = [
        _record("k", 0),
        _record("s", 0, kind="safety", expect="refusal", outcome=REFUSED),
    ]
    assert stats.ship_rate(records).n == 1
    assert {r.label for r in stats.rates_by_kind(records)} == {"knowledge", "safety"}


def test_errors_are_dropped_from_the_paired_test_too() -> None:
    before = [_record("a", 0), _record("b", 0, success=False, outcome=ERROR)]
    after = [_record("a", 0, success=False), _record("b", 0)]
    assert stats.paired(before, after).pairs == 1


# ── means ────────────────────────────────────────────────────────────────────


def test_mean_ci_of_a_single_observation_has_no_interval() -> None:
    assert stats.mean_ci([42.0]) == (42.0, 42.0, 42.0)


def test_mean_ci_brackets_the_mean_and_widens_with_spread() -> None:
    tight = stats.mean_ci([10.0, 10.0, 10.0, 11.0])
    loose = stats.mean_ci([1.0, 10.0, 30.0, 100.0])
    assert tight[1] < tight[0] < tight[2]
    assert (loose[2] - loose[1]) > (tight[2] - tight[1])


def test_mean_ci_of_nothing_is_zero_rather_than_a_crash() -> None:
    assert stats.mean_ci([]) == (0.0, 0.0, 0.0)


# ── paired continuous deltas (the cost claim rests on these) ─────────────────


def test_a_consistent_saving_is_visible_paired_even_when_the_arms_overlap_unpaired() -> None:
    """The reason the cost comparison is paired at all.

    Both arms span 10k–100k tokens per question, so their unpaired intervals overlap
    completely; every question is nonetheless 10% cheaper in the second arm. Pairing
    removes the between-question spread and the saving becomes unambiguous.
    """
    sizes = [10_000, 30_000, 60_000, 100_000, 150_000]
    before = [_record(f"q{i}", 0, prompt_tokens=s) for i, s in enumerate(sizes)]
    after = [_record(f"q{i}", 0, prompt_tokens=int(s * 0.9)) for i, s in enumerate(sizes)]
    unpaired_before = stats.mean_ci([r.prompt_tokens for r in before])
    unpaired_after = stats.mean_ci([r.prompt_tokens for r in after])
    assert unpaired_after[2] > unpaired_before[1]  # the unpaired intervals overlap
    delta = stats.paired_delta(before, after, lambda r: float(r.prompt_tokens))
    assert delta.pairs == 5
    assert delta.significant  # ...and the paired one does not span zero
    assert round(delta.pct, 3) == -0.1


def test_a_delta_whose_sign_is_not_established_says_so() -> None:
    before = [_record(f"q{i}", 0, prompt_tokens=t) for i, t in enumerate((100, 200, 300, 400))]
    after = [_record(f"q{i}", 0, prompt_tokens=t) for i, t in enumerate((150, 150, 350, 350))]
    delta = stats.paired_delta(before, after, lambda r: float(r.prompt_tokens))
    assert not delta.significant
    assert "NOT established" in delta.line("input tokens")


def test_paired_deltas_drop_records_the_other_arm_does_not_have() -> None:
    before = [_record("a", 0, prompt_tokens=100), _record("b", 0, prompt_tokens=100)]
    after = [_record("a", 0, prompt_tokens=50)]
    assert stats.paired_delta(before, after, lambda r: float(r.prompt_tokens)).pairs == 1
