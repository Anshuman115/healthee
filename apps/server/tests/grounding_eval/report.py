"""Turn records into text a person can act on — n and uncertainty on every line.

Nothing here computes; it prints what ``stats`` computed. The rule the format enforces
is that a rate NEVER appears without its n and its 95% interval, and a comparison never
appears without its p value and an explicit sentence about significance. A number in
this output that is not measured (the money figure) says which assumption it rests on.
"""

from __future__ import annotations

from collections.abc import Sequence

from tests.grounding_eval import stats
from tests.grounding_eval.records import EvalRun, RunRecord

# docs/PRICING.md §6: the default tier is billed $0.50/M input, $3.00/M output. Output is
# billed on tokens produced INCLUDING the reasoning a reasoning model spends invisibly,
# which is why the reasoning share is printed rather than folded away.
USD_PER_M_INPUT = 0.50
USD_PER_M_OUTPUT = 3.00


def _cost_usd(records: Sequence[RunRecord]) -> float:
    prompt = sum(r.prompt_tokens for r in records)
    completion = sum(r.completion_tokens for r in records)
    return prompt / 1e6 * USD_PER_M_INPUT + completion / 1e6 * USD_PER_M_OUTPUT


def _mean_line(label: str, values: Sequence[float], unit: str = "") -> str:
    mean, lo, hi = stats.mean_ci(values)
    return f"{label:<28} {mean:9.1f}{unit}  [95% CI {lo:.1f} – {hi:.1f}]  n={len(values)}"


def summary(run: EvalRun) -> str:
    """The whole arm in one block: rates with intervals, spend, and the weak spots."""
    records = run.records
    ok = stats.scored(records)
    answers = stats.answering(records)
    lines = [
        f"── {run.label} ── commit {run.commit} · set {run.question_set} · "
        f"{run.repeats} repeat(s) · {run.started_at}",
        "",
        "SHIP RATE (the owner saw an answer we paid for)",
        "  " + stats.ship_rate(records).line(),
        "",
        "by kind",
    ]
    lines += ["  " + rate.line() for rate in stats.rates_by_kind(records)]
    lines += ["", "by question"]
    lines += ["  " + rate.line() for rate in stats.rates_by_question(records)]
    lines += ["", "OUTCOMES"]
    for outcome in sorted({r.outcome for r in records}):
        lines.append(f"  {outcome:<10} {sum(1 for r in records if r.outcome == outcome):>3}")
    shipped_citations = [len(r.citations) for r in answers if r.success]
    coach_rounds = [r.tool_rounds for r in ok if r.surface == "coach"]
    lines += ["", "PER QUESTION (means over every scored run)"]
    lines += [
        "  " + _mean_line("citations / shipped answer", shipped_citations),
        "  " + _mean_line("llm calls", [r.llm_calls for r in ok]),
        "  " + _mean_line("tool rounds (coach)", coach_rounds),
        "  " + _mean_line("input tokens", [r.prompt_tokens for r in ok]),
        "  " + _mean_line("output tokens (incl. reasoning)", [r.completion_tokens for r in ok]),
        "  " + _mean_line("reasoning tokens", [r.reasoning_tokens for r in ok]),
        "  " + _mean_line("latency", [r.latency_ms for r in ok], " ms"),
    ]
    lines += ["", "SPEND (measured tokens × PRICING.md §6's rates — the RATE is the assumption)"]
    lines += [
        f"  input {sum(r.prompt_tokens for r in records):,} tok · "
        f"output {sum(r.completion_tokens for r in records):,} tok "
        f"(of which {sum(r.reasoning_tokens for r in records):,} reasoning) "
        f"⇒ ${_cost_usd(records):.2f} for this run",
    ]
    causes = stats.failure_causes(records)
    if causes:
        lines += ["", "WHY ANSWERS DID NOT SHIP (issue causes, commonest first)"]
        lines += [f"  {count:>3}  {cause}" for cause, count in causes]
    unmetered = sum(r.unmetered_calls for r in records)
    if unmetered:
        lines.append(f"  ⚠ {unmetered} call(s) reported NO usage — spend is a lower bound")
    errored = stats.errors(records)
    if errored:
        lines += ["", f"⚠ {len(errored)} ERROR record(s), excluded from every rate above:"]
        lines += [f"  {r.question_id}#{r.repeat}: {r.error}" for r in errored[:10]]
    return "\n".join(lines)


def comparison(first: EvalRun, second: EvalRun) -> str:
    """Two arms, paired on (question, repeat) — with the p value and a plain verdict."""
    lines = [
        f"── {first.label} ({first.commit})  →  {second.label} ({second.commit})",
        "",
    ]
    if first.question_set != second.question_set:
        lines.append(
            "⚠ THE QUESTION SETS DIFFER "
            f"({first.question_set} vs {second.question_set}) — these two runs are not "
            "comparable; re-run both arms on one set."
        )
        return "\n".join(lines)
    a_rate, b_rate = (
        stats.ship_rate(first.records, "before"),
        stats.ship_rate(second.records, "after"),
    )
    test = stats.paired(first.records, second.records)
    lines += [
        "SHIP RATE",
        "  " + a_rate.line(),
        "  " + b_rate.line(),
        "",
        "PAIRED TEST (McNemar, exact two-sided binomial on the discordant pairs)",
        f"  {test.pairs} pair(s): both shipped {test.both} · neither {test.neither} · "
        f"only before {test.b_only} · only after {test.c_only}",
        f"  ⇒ {test.verdict}",
        "",
        "BY KIND (before → after)",
    ]
    before_kinds = {r.label: r for r in stats.rates_by_kind(first.records)}
    for after in stats.rates_by_kind(second.records):
        before = before_kinds.get(after.label)
        shown = f"{before.successes}/{before.n}" if before else "—"
        lines.append(
            f"  {after.label:<18} {shown:>7} → {after.successes}/{after.n}"
            f"   (after: {after.rate:5.1%} [{after.ci[0]:.0%}–{after.ci[1]:.0%}])"
        )
    lines += ["", "COST PER RUN"]
    for run in (first, second):
        ok = stats.scored(run.records)
        mean, lo, hi = stats.mean_ci([r.prompt_tokens for r in ok])
        lines.append(
            f"  {run.label:<10} input {sum(r.prompt_tokens for r in run.records):>9,} tok · "
            f"mean/question {mean:7.0f} [{lo:.0f}–{hi:.0f}] · ${_cost_usd(run.records):.2f}"
        )
    lines += ["", "PAIRED per-question deltas (after − before; the unpaired means above overlap"]
    lines += ["by construction — between-question spread dwarfs the effect)"]
    for label, value in (
        ("input tokens", lambda r: float(r.prompt_tokens)),
        ("output tokens", lambda r: float(r.completion_tokens)),
        ("llm calls", lambda r: float(r.llm_calls)),
        ("tool rounds", lambda r: float(r.tool_rounds)),
        ("citations", lambda r: float(len(r.citations))),
    ):
        lines.append("  " + stats.paired_delta(first.records, second.records, value).line(label))
    return "\n".join(lines)
