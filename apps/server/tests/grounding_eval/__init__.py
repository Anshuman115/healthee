"""The GROUNDING EVAL — does a change make the product's answers better or worse?

The project could not answer that question, and two separate pieces of work stopped
short because of it: the cost work could not test whether four evidence notes ground an
answer as well as six (the evidence block is 65–83% of every prompt — the biggest cost
lever left), and the alias fix could only report "58% → 53% at n=59, ≈0.5σ apart", i.e.
*not measurably worse, not proven better*. A number with no interval attached cannot
tell those two apart, so neither change could be defended or refuted.

This package runs a FIXED question set against the REAL model through the real choke
point, and reports, with n and a 95% interval printed beside every rate:

  * **ship rate** — the headline. An answer that fails its gates twice costs a
    full-context call AND its nudged retry and then ships the honest fallback: the owner
    sees nothing and we paid double. Measured 2026-08-01, ~40% of nightly generations
    ended that way, so answer quality is a cost lever roughly the size of the prompt.
  * refusal correctness on the safety questions (a floor, not a rate to optimise),
  * citations per shipped answer, LLM calls, tool rounds,
  * provider-COUNTED tokens (``ChatResponse.usage``), input / output / reasoning.

**It costs real money and hits the network, so it is never part of the normal suite.**
Nothing here is named ``test_*`` except the pure-arithmetic unit tests beside it, which
take no network and no database and DO run in the suite — the statistics are the part
that must not be wrong, because a wrong interval is worse than no interval.

Run it (from ``apps/server``, with a reachable TimescaleDB and an OpenRouter key):

    POSTGRES_HOST=localhost POSTGRES_PORT=5558 POSTGRES_DB=healthee \\
    POSTGRES_USER=healthee POSTGRES_PASSWORD=… \\
      uv run python -m tests.grounding_eval run --repeats 3 --out before.json

    # …change retrieval, then…
      uv run python -m tests.grounding_eval run --repeats 3 --out after.json
      uv run python -m tests.grounding_eval compare before.json after.json

``run`` seeds the throwaway contract dataset into that database — do not point it at
anything you care about. One run of the shipped set at ``--repeats 3`` is 48 questions
and measured ~2.0M input tokens (~$1.10 at PRICING.md's assumed rates).

The arms are two RUNS of the same code, not a flag inside it: comparing "before" and
"after" means checking out each side and running it. A harness that carried the old
behaviour as an option would be a second definition of retrieval, and would rot.
"""
