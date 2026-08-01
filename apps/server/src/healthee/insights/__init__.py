"""The intelligence layer: the grounded-ask choke point + LLM insight surfaces.

``pipeline.py`` IS the choke point: the deterministic refusal gate → v2-native context →
manifest-ranked retrieval → the one LLM transport call → hard OUTPUT GUARDRAILS
(``output_guard``) → the BLOCKING citation validator → the anti-hallucination gate →
one nudged retry and then the honest fallback (never unvalidated text).

**Two surfaces run it, and they run the same code.** ``grounded_ask`` (``grounded.py``)
is the non-conversational one — ``surfaces``, ``notable``, ``coaching``, ``jobs.recs``,
``jobs.briefing``, ``challenges.generate``/``program_generate`` are thin tasks over it.
``run_coach`` (``coach.py``) is the conversational one; it needs a bounded tool loop, so
it supplies a different message layout and a different turn shape — and nothing else.
The coach used to re-implement the sequence from the same primitives
(*enforced-equivalent, not routed-through*), which meant every new rule had to be
mirrored by hand; that is no longer true, and no longer documented as true.
"""

from __future__ import annotations

from healthee.insights.grounded import GroundedResult, grounded_ask

__all__ = ["GroundedResult", "grounded_ask"]
