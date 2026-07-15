"""Read-path service layer (WP7).

Ports the legacy read-endpoint payload builders to v2-native reads: every query
selects from the v2 tables (``derived_daily``, ``sample``, ``sleep_session``,
``workout``, ``manual_entry``, ``weight_log``, ``profile``, ``gps_track`` /
``gps_point``) — never a v1 compat view (``metric_sample`` / ``session``) and
never a ``source=`` filter (v2 has no source column). The routers stay thin
(auth → call a service → shape response); all shaping logic lives here.

The response SHAPES match legacy so the installed mobile app keeps working at
Phase-6 cutover. LLM-generated narrative fields (the daily "action", sleep
"tonight" coaching, per-metric insights) are OWNED BY WP5 and are omitted here
with a ``# WP5:`` marker — this layer only produces the metric/data content.
"""

from __future__ import annotations
