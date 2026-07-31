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

Modules
-------
``metrics``   the registry — which metrics are trackable and where each lives
``series``    daily series, the owner's baseline, and protected (rough-night) days
``evaluate``  live progress for an adopted challenge
``adapt``     the deterministic difficulty adapter

Dependencies run downward only (standards §"one responsibility"): ``core``,
``derive`` and ``analytics``. Nothing here imports ``read``, ``api`` or
``insights``.
"""

from __future__ import annotations

from healthee.challenges.adapt import suggest_adaptation
from healthee.challenges.evaluate import evaluate_challenge
from healthee.challenges.metrics import CHALLENGE_METRICS, ChallengeMetric, round_target, spec
from healthee.challenges.series import metric_series, protected_days, recent_value

__all__ = [
    "CHALLENGE_METRICS",
    "ChallengeMetric",
    "evaluate_challenge",
    "metric_series",
    "protected_days",
    "recent_value",
    "round_target",
    "spec",
    "suggest_adaptation",
]
