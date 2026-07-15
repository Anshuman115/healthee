"""Ingest layer: validate the /ingest/helio payload, upsert raw + typed rows,
trigger derivation for the days a push touched.

The single entry point is `ingest_helio` (service.py); the router calls only
that. Payload shapes are the pydantic models in `models.py` and match the mobile
client's push body exactly (wire-compatible with the installed app).
"""

from __future__ import annotations

from healthee.ingest.models import HelioPayload
from healthee.ingest.service import IngestSummary, ingest_helio

__all__ = ["HelioPayload", "IngestSummary", "ingest_helio"]
