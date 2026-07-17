"""The intelligence layer: the grounded-ask choke point + LLM insight surfaces.

``grounded_ask`` (``grounded.py``) is the pipeline: deterministic refusal gating →
v2-native context → manifest-ranked retrieval → one completion → hard OUTPUT
GUARDRAILS (``output_guard``) → a BLOCKING citation validator (honest fallback,
never unvalidated text). The insight surfaces (``surfaces.py``, ``notable.py``,
``coaching.py``) are thin tasks over it, as are ``jobs.recs`` / ``jobs.briefing``.

⚠ **NOT every LLM call goes through it, though this docstring used to say so.**
``coach.py`` needs its own tool-calling loop, so it re-implements the same sequence
from the same primitives — enforced-equivalent, not routed-through. Every rule added
to ``grounded_ask`` must be mirrored there or the coach silently misses it; see
``grounded.py``'s docstring and INTELLIGENCE.md §4 for the full statement.
"""

from __future__ import annotations

from healthee.insights.grounded import GroundedResult, grounded_ask

__all__ = ["GroundedResult", "grounded_ask"]
