"""The challenges deterministic engine (WP-C1, ``docs/CHALLENGES.md`` §1 + §5.2).

A challenge is a **measurable rule** — a ``metric`` + ``comparator`` +
``target_value`` over a ``cadence``/``window_days`` — auto-tracked from the owner's
own derived data. This package is the deterministic substrate under that: the
metric registry, the daily series and baseline reads, live progress with
recovery-aware streak protection, and the auto-calibration rule.

Everything here is a **pure function over one owner's window** taking the caller's
cursor. There is no persistence, no HTTP, and no LLM — the design law of the whole
track is that the numbers are deterministic and only the prose is generated
(CHALLENGES.md §0), so nothing in this package may ever ask a model for a value.
Lifecycle and endpoints are WP-C2; generation is WP-C3.

WP-C2 adds the persistence half on top of that substrate — the state machine and
the frozen outcome ledger. It still holds the design law: the lifecycle decides
*when* using the engine's numbers and never asks a model for one.

WP-C3 adds generation, and it is the ONE place in this package where a model writes
anything. The design law survives it intact by inversion: the model authors the whole
challenge and two deterministic gates decide what ships — the target must sit in the
owner's own progressive-overload band (``bounds``), and the copy must be citable
through the blocking choke point. Nothing in the generation path rewrites a number.

Modules
-------
``metrics``      the registry — which metrics are trackable and where each lives
``series``       daily series, the owner's baseline, and protected (rough-night) days
``evaluate``     live progress for an adopted challenge
``adapt``        the deterministic difficulty adapter
``recovery_guard`` the ONE "do not push this owner harder" rule (``levers`` + ``adapt``)
``store``        the only place challenge SQL lives (owner-scoped rows)
``lifecycle``    suggested → active → completed | expired | abandoned
``confounds``    the structured reasons to distrust an outcome
``ledger``       the frozen before/after — what we are willing to claim a challenge did
``bounds``       Gate A — the baseline-bounds check on a proposed target
``gen_context``  the generation inputs the choke point does not already supply
``gen_prompt``   the task text and the vocabularies a generated row must use
``screen``       every gate applied to one proposal
``generate``     the generation pipeline (the WP-C5 entry point)

Dependencies run downward only (standards §"one responsibility"): ``core``, ``derive``
and ``analytics``, plus — from WP-C3 and only in the generation modules — ``insights``,
which is where the choke point lives. That edge is the same one ``jobs.recs`` already
has, and it runs one way: ``insights`` does not import ``challenges``. WP-C5 will make
the coach *call* ``generate`` rather than reimplement it, so the arrow stays pointed
this way and the gates cannot be forked.

``recovery_guard`` adds one more downward edge, to ``read`` — ``recovery_band`` and
``active_illness_severity``, the SAME two functions the recovery page answers with.
Reading them is the whole point: "under-recovered" must not mean one thing on the
recovery card and another in the challenges engine (CLAUDE.md — one definition per
metric). That edge also runs one way; ``read`` does not import ``challenges``, and
nothing here imports ``api``.
"""

from __future__ import annotations

from healthee.challenges.adapt import suggest_adaptation
from healthee.challenges.evaluate import evaluate_challenge
from healthee.challenges.generate import generate_challenges
from healthee.challenges.lifecycle import (
    MAX_ACTIVE,
    abandon,
    adopt,
    finalize_due,
    list_challenges,
)
from healthee.challenges.metrics import CHALLENGE_METRICS, ChallengeMetric, round_target, spec
from healthee.challenges.series import metric_series, protected_days, recent_value

__all__ = [
    "CHALLENGE_METRICS",
    "MAX_ACTIVE",
    "ChallengeMetric",
    "abandon",
    "adopt",
    "evaluate_challenge",
    "finalize_due",
    "generate_challenges",
    "list_challenges",
    "metric_series",
    "protected_days",
    "recent_value",
    "round_target",
    "spec",
    "suggest_adaptation",
]
