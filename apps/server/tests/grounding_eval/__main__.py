"""The CLI: ``run`` one arm (paid, networked), ``compare`` two saved arms (free).

    uv run python -m tests.grounding_eval run --repeats 3 --out before.json
    uv run python -m tests.grounding_eval compare before.json after.json

``run`` TRUNCATES and re-seeds the database it is pointed at — never point it at data
anyone needs. It is deliberately noisy per question: a paid run must be interruptible the
moment its answers start coming back as errors.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from tests.grounding_eval import records, report
from tests.grounding_eval.questions import by_kind
from tests.grounding_eval.runner import run_questions

from healthee.core.db import close_pool


def _run(args: argparse.Namespace) -> int:
    questions = by_kind(set(args.only) if args.only else None)
    if not questions:
        print(f"no questions match --only {args.only}", file=sys.stderr)
        return 2
    run = records.new_run(args.label, questions, args.repeats)
    total = len(questions) * args.repeats
    print(f"{args.label}: {len(questions)} question(s) × {args.repeats} = {total} paid runs\n")
    for index, record in enumerate(run_questions(run, questions, args.repeats), start=1):
        print(
            f"[{index:>3}/{total}] {record.question_id:<20} {record.outcome:<9} "
            f"calls={record.llm_calls} tools={record.tool_rounds} "
            f"in={record.prompt_tokens:>6} cites={len(record.citations)} "
            f"{record.latency_ms:>6} ms {record.error}",
            flush=True,  # a redirected run must still be watchable line by line
        )
    records.save(run, Path(args.out))
    print("\n" + report.summary(run))
    print(f"\nwritten: {args.out}")
    close_pool()  # the pool's worker threads outlive main() otherwise, and say so loudly
    return 0


def _compare(args: argparse.Namespace) -> int:
    first, second = records.load(Path(args.before)), records.load(Path(args.after))
    print(report.summary(first) + "\n\n" + report.summary(second) + "\n")
    print(report.comparison(first, second))
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="tests.grounding_eval", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    run_cmd = sub.add_parser("run", help="run the set against the REAL model (costs money)")
    run_cmd.add_argument("--repeats", type=int, default=3, help="runs per question (default 3)")
    run_cmd.add_argument("--out", required=True, help="where to write the arm's JSON")
    run_cmd.add_argument("--label", default="arm", help="a name for this arm")
    run_cmd.add_argument("--only", nargs="*", help="restrict to these question kinds")
    run_cmd.set_defaults(func=_run)

    cmp_cmd = sub.add_parser("compare", help="paired comparison of two saved arms (free)")
    cmp_cmd.add_argument("before")
    cmp_cmd.add_argument("after")
    cmp_cmd.set_defaults(func=_compare)

    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
