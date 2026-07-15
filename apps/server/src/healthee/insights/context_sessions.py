"""V2-native context: sleep sessions + physiology overlays, manual logs, findings.

The session/log/finding half of the context builder (paired with ``context.py``).
Reads the v2 tables directly — ``sleep_session`` (stage minutes live in columns,
not a v1 ``summary`` JSON), ``sample`` (v2 metric names: hr/hrv/spo2/
respiratory_rate/skin_temp_c), ``manual_entry`` — so nothing depends on the dead
``source='zepp_cloud'`` filter or v1 names (INTELLIGENCE §5.4).

Personal findings are the user's own FDR-significant n=1 patterns. They are
rendered as ``[personal_finding:<id>]`` tokens and labelled NOT citations, so the
model (and the validator) keep them distinct from population research (§3).
"""

from __future__ import annotations

import re

from healthee.analytics.finding import get_significant_findings

_USER_TZ = "Asia/Kolkata"
_WORD = re.compile(r"[a-z0-9_]+")

# Sleep-window physiology overlays: v2 sample metric name → column label.
_OVERLAY_METRICS: tuple[tuple[str, str], ...] = (
    ("hr", "HRavg"),
    ("hrv", "HRV"),
    ("spo2", "SpO2"),
    ("respiratory_rate", "resp"),
    ("skin_temp_c", "temp"),
)


def sleep_section(cur, days: int) -> str:
    """Recent sleep sessions with stage minutes + physiology overlays per night."""
    cur.execute(
        """
        SELECT (s.end_ts AT TIME ZONE %s)::date AS d, s.kind,
               to_char(s.start_ts AT TIME ZONE %s, 'HH24:MI'),
               to_char(s.end_ts   AT TIME ZONE %s, 'HH24:MI'),
               s.score, s.light_min, s.deep_min, s.rem_min, s.wake_min,
               ROUND(AVG(CASE WHEN m.metric='hr'                THEN m.value END))::int,
               ROUND(AVG(CASE WHEN m.metric='hrv'               THEN m.value END))::int,
               ROUND(AVG(CASE WHEN m.metric='spo2'              THEN m.value END))::int,
               ROUND(AVG(CASE WHEN m.metric='respiratory_rate'  THEN m.value END))::int,
               ROUND(AVG(CASE WHEN m.metric='skin_temp_c'       THEN m.value END)::numeric, 1)
        FROM sleep_session s
        LEFT JOIN sample m ON m.ts >= s.start_ts AND m.ts < s.end_ts
        WHERE (s.end_ts AT TIME ZONE %s)::date > (current_date - %s::int)
        GROUP BY s.start_ts, s.end_ts, s.kind, s.score,
                 s.light_min, s.deep_min, s.rem_min, s.wake_min
        ORDER BY d DESC, s.start_ts
        """,
        (_USER_TZ, _USER_TZ, _USER_TZ, _USER_TZ, days),
    )
    rows = cur.fetchall()
    if not rows:
        return ""
    lines = [
        f"## Sleep sessions with physiology overlays (last {days} days)",
        "| date | kind | start | end | score | light | deep | rem | wake | "
        + " | ".join(label for _, label in _OVERLAY_METRICS)
        + " |",
        "|" + "---|" * 14,
    ]
    for r in rows:
        lines.append("| " + " | ".join("-" if x is None else str(x) for x in r) + " |")
    return "\n".join(lines)


def manual_entries_section(cur, days: int) -> str:
    """Recent user-logged events (caffeine/alcohol/meditation/exercise/fasting/…)."""
    cur.execute(
        """
        SELECT ts AT TIME ZONE %s, kind, name, amount, unit, notes
        FROM manual_entry
        WHERE (ts AT TIME ZONE %s)::date > (current_date - %s::int)
        ORDER BY ts DESC LIMIT 200
        """,
        (_USER_TZ, _USER_TZ, days),
    )
    rows = cur.fetchall()
    if not rows:
        return ""
    lines = [f"## Manual entries (last {days} days, {_USER_TZ})"]
    for ts, kind, name, amount, unit, notes in rows:
        bits = [ts.strftime("%Y-%m-%d %H:%M"), kind]
        if name:
            bits.append(f"name={name}")
        if amount is not None and unit:
            bits.append(f"{amount:g}{unit}")
        if notes:
            bits.append(f"notes={notes}")
        lines.append("- " + " | ".join(bits))
    return "\n".join(lines)


def _rank_findings(findings: list[dict], question: str | None) -> list[dict]:
    """Order findings by |effect|, floated toward any that name a metric in the question."""
    tokens = set(_WORD.findall(question.lower())) if question else set()

    def key(f: dict) -> tuple[int, float]:
        named = bool(
            tokens & {f.get("metric_a", ""), f.get("metric_b", ""), f.get("event_kind", "")}
        )
        return (0 if named else 1, -abs(f.get("effect_size") or 0.0))

    return sorted(findings, key=key)


def findings_section(question: str | None) -> str:
    """The user's FDR-significant personal patterns — n=1, NOT citations.

    Ranked toward the question when one is given. Each is tagged with a
    ``[personal_finding:<id>]`` token so the model references it as personal
    evidence (the validator treats these as distinct from note ids).
    """
    findings = get_significant_findings(limit=50)
    if not findings:
        return ""
    findings = _rank_findings(findings, question)[:12]
    lines = [
        f"## PERSONAL FINDINGS — patterns in YOUR data ({len(findings)} shown, FDR q ≤ 0.10)",
        "These are n=1 empirical observations — descriptive, NOT citations. Reference "
        "one as `[personal_finding:<metric_a>]` and still attach a real `[note_id]` for "
        "any interpretive claim built on it.",
    ]
    for f in findings:
        token = f.get("metric_a") or f.get("kind") or "finding"
        notes = ", ".join(f.get("research_note_ids") or [])
        note_str = f"; research: {notes}" if notes else ""
        lines.append(
            f"- `[personal_finding:{token}]` {f['description']} "
            f"_({f['effect_metric']}={f['effect_size']:+.2f}, q={f['q_value']:.3f}, "
            f"n={f['n_samples']}{note_str})_"
        )
    return "\n".join(lines)
