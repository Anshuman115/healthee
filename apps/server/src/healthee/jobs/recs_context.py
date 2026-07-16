"""V2-native "today's signals" preamble for the recommendations engine.

Legacy ``llm/recs.py`` built its own big context off the v1 compat views
(``source='derived'`` filters, v1 metric names) and read the profile from a JSON
file (recs.py:227). This surfaces the same recs-specific levers — profile, the
weekly MVPA gap, the recovery ceiling, and the strongest personal findings — but
reads them V2-NATIVE: the ``profile`` DB table and the v2 read-layer payloads
(``derived_daily`` under the hood), never a JSON file or a ``source=`` filter.

The rich per-metric context (today snapshot, trends, sleep, baselines, anomalies,
findings table) is added by the choke point's own ``build_context`` when
``recs.generate_recs`` calls ``grounded_ask`` — this preamble only adds the
aggregate levers that ``build_context`` does not compute as gaps/targets.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.analytics.finding import get_significant_findings
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import user_today
from healthee.read.fitness import mvpa_payload
from healthee.read.recovery import recovery_score_payload

_TARGET_MVPA_MIN = 150  # WHO weekly moderate-to-vigorous target [mvpa_minutes_mortality]


def build_recs_signals(user_id: UUID, tz: str) -> str:
    """Assemble the compact v2-native signals block the recs prompt anchors to."""
    with tenant_transaction(user_id) as cur:
        parts = [
            _profile_line(cur, user_id, user_today(tz)),
            _recovery_line(cur, user_id, tz),
            _mvpa_line(cur, user_id, tz),
        ]
    parts.append(_findings_block(user_id))
    return "\n".join(p for p in parts if p)


def _profile_line(cur, user_id: UUID, today: date) -> str:
    """Profile from the DB ``profile`` table — never the legacy JSON file."""
    cur.execute("SELECT sex, height_cm, dob FROM profile WHERE user_id = %s", (user_id,))
    row = cur.fetchone()
    if not row:
        return "- Profile: not configured."
    sex, height_cm, dob = row
    age = _age(dob, today) if dob else None
    bits = [f"age {age}" if age is not None else "age unknown", sex or "sex unknown"]
    if height_cm:
        bits.append(f"{height_cm:.0f} cm")
    return "- Profile: " + ", ".join(bits) + "."


def _age(dob: date, today: date) -> int:
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def _recovery_line(cur, user_id: UUID, tz: str) -> str:
    """Recovery band SETS today's intensity ceiling (recs must respect it)."""
    payload = recovery_score_payload(cur, user_id, tz)
    if not payload:
        return ""
    return (
        f"- Recovery {payload['recovery']}/100 ({payload['band']}) "
        f"[recovery_readiness] — SETS today's intensity ceiling: high ⇒ can push, "
        f"moderate ⇒ Zone 2 only, low ⇒ rest + protect sleep. Never prescribe a hard "
        f"session on low recovery."
    )


def _mvpa_line(cur, user_id: UUID, tz: str) -> str:
    """This week's MVPA vs the 150-min target, framed as the remaining gap."""
    payload = mvpa_payload(cur, user_id, tz)
    if not payload:
        return ""
    week = payload["week_min"]
    gap = max(0, _TARGET_MVPA_MIN - week)
    return (
        f"- MVPA this week: {week}/{_TARGET_MVPA_MIN} min (gap {gap} min) [mvpa_minutes_mortality]."
    )


def _findings_block(user_id: UUID) -> str:
    """The strongest personal findings (incl. caffeine/alcohol cutoffs), cited."""
    findings = get_significant_findings(user_id, limit=6)
    if not findings:
        return "- Personal findings: none above the significance threshold yet."
    lines = ["- Personal findings (your own n=1 patterns — cite as [personal_finding:…]):"]
    for f in findings:
        notes = ", ".join(f["research_note_ids"] or []) or "—"
        lines.append(f"  · {f['description']} (notes: {notes})")
    return "\n".join(lines)
