"""The intelligence layer: the grounded-ask choke point + LLM insight surfaces.

Every LLM call in the product goes through ``grounded_ask`` (``grounded.py``):
deterministic refusal gating → v2-native context → manifest-ranked retrieval →
one completion → a BLOCKING citation validator (honest fallback, never unvalidated
text). The insight surfaces (``surfaces.py``, ``notable.py``) are thin tasks over
that pipeline; the coach (WP5b) will reuse it via the ``allow_tools`` seam.
"""

from __future__ import annotations

from healthee.insights.grounded import GroundedResult, grounded_ask

__all__ = ["GroundedResult", "grounded_ask"]
