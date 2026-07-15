"""Notable shifts — scan every daily metric for deviations, ground each meaning.

Legacy ``/api/notable``: detect anomalies across all daily metrics, dedupe to the
single most-extreme shift per metric, and have the LLM write what each means. Here
the "meaning" text is produced through the choke point (``grounded_ask``) so it is
citation-validated like every other surface — one batched, validated pass whose
lines are mapped back to the shifts. Cached per day.
"""

from __future__ import annotations

import time

from healthee.analytics.anomalies import Anomaly, detect
from healthee.insights.cache import get_cached, set_cached, today_iso
from healthee.insights.grounded import grounded_ask
from healthee.read.meta import METRIC_META

_MAX_SHIFTS = 8


def _label(metric: str) -> str:
    return METRIC_META.get(metric, {}).get("label", metric.replace("_", " "))


def _dedupe(anomalies: list[Anomaly]) -> list[Anomaly]:
    """Keep the most-extreme shift per metric, strongest first, capped."""
    by_metric: dict[str, Anomaly] = {}
    for a in anomalies:
        if a.metric not in by_metric or abs(a.z) > abs(by_metric[a.metric].z):
            by_metric[a.metric] = a
    return sorted(by_metric.values(), key=lambda a: -abs(a.z))[:_MAX_SHIFTS]


def _shift_item(a: Anomaly) -> dict:
    return {
        "date": a.when.isoformat(),
        "metric": a.metric,
        "label": _label(a.metric),
        "value": round(a.value, 1),
        "median": round(a.baseline.median, 1) if a.baseline.median is not None else None,
        "z": round(a.z, 2),
        "direction": a.direction,
        "note_ids": a.research_note_ids,
        "meaning": "",
    }


def _meaning_task(items: list[dict]) -> str:
    lines = [
        f"- {it['label']}: {it['value']} on {it['date']}, {it['z']:+}σ {it['direction']} "
        f"vs my median {it['median']}"
        for it in items
    ]
    return (
        "For each of my recent notable metric shifts below, write ONE short line on what "
        "it means for me, prefixed EXACTLY with the metric label and a colon. Cite "
        "[note_id] for any health claim; if none applies write 'No strong evidence in our "
        "base for this.' No diagnosis.\n\nSHIFTS:\n" + "\n".join(lines)
    )


def _attach_meanings(items: list[dict], text: str) -> None:
    """Map each 'Label: meaning' line of the validated answer onto its shift."""
    lines = [ln.strip("-• ").strip() for ln in text.splitlines() if ":" in ln]
    for it in items:
        prefix = it["label"].lower() + ":"
        for ln in lines:
            if ln.lower().startswith(prefix):
                it["meaning"] = ln[len(prefix) :].strip()
                break


def notable(*, refresh: bool = False) -> dict:
    """Deduped notable shifts across daily metrics, each with a grounded meaning."""
    if not refresh:
        cached = get_cached("notable_insight")
        if cached is not None:
            return cached
    items = [_shift_item(a) for a in _dedupe(detect(days_back=14, window_days=30))]
    validated = True
    if items:
        result = grounded_ask(
            _meaning_task(items), metrics=[it["metric"] for it in items], context_days=14
        )
        validated = result.validated
        _attach_meanings(items, result.text)
    out = {
        "items": items,
        "date": today_iso(),
        "generated_at": int(time.time()),
        "validated": validated,
    }
    if validated:
        set_cached("notable_insight", out)
    return out
