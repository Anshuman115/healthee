"""The Finding record and its ``finding``-table persistence.

A Finding is one discovered pattern — a pairwise correlation, an event-effect, or
a personal cutoff. The dataclass and the UPSERT/read SQL are ported verbatim from
legacy ``correlations.py``; the only change is routing through the pooled
``core.db`` connection instead of a module-local ``_connect()`` (standards §2:
"DB access only via core/db").
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from uuid import UUID

from healthee.core.db import tenant_transaction
from healthee.derive._common import Cur

# finding.effect_metric values (which effect-size the number is).
EFFECT_SPEARMAN = "spearman_r"
EFFECT_MANN_WHITNEY = "mann_whitney_rb"  # rank-biserial


@dataclass
class Finding:
    """One discovered pattern, shaped for the ``finding`` table."""

    kind: str
    description: str
    metric_a: str
    metric_b: str | None
    event_kind: str | None
    lag_days: int
    effect_size: float
    effect_metric: str
    p_value: float
    q_value: float | None
    n_samples: int
    significant: bool
    research_note_ids: list[str] = field(default_factory=list)
    details: dict = field(default_factory=dict)


_INSERT_SQL = """
    INSERT INTO finding
      (user_id, kind, description, metric_a, metric_b, event_kind, lag_days,
       effect_size, effect_metric, p_value, q_value, n_samples,
       significant, research_note_ids, details)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)
"""

_UPSERT_TAIL = """
    ON CONFLICT (user_id, kind, metric_a, metric_b, event_kind, lag_days)
    DO UPDATE SET
      computed_at = now(),
      description = EXCLUDED.description,
      effect_size = EXCLUDED.effect_size,
      effect_metric = EXCLUDED.effect_metric,
      p_value = EXCLUDED.p_value,
      q_value = EXCLUDED.q_value,
      n_samples = EXCLUDED.n_samples,
      significant = EXCLUDED.significant,
      research_note_ids = EXCLUDED.research_note_ids,
      details = EXCLUDED.details
"""


def _params(user_id: UUID, f: Finding) -> tuple:
    """Positional params for the INSERT (empty strings for the null-key columns
    so the UNIQUE conflict target matches — those columns are NOT NULL)."""
    return (
        user_id,
        f.kind,
        f.description,
        f.metric_a,
        f.metric_b or "",
        f.event_kind or "",
        f.lag_days,
        f.effect_size,
        f.effect_metric,
        f.p_value,
        f.q_value,
        f.n_samples,
        f.significant,
        f.research_note_ids,
        json.dumps(f.details),
    )


def persist_findings(user_id: UUID, findings: list[Finding]) -> int:
    """UPSERT ``user_id``'s findings on their natural key. Returns the count written."""
    if not findings:
        return 0
    with tenant_transaction(user_id) as cur:
        for f in findings:
            cur.execute(_INSERT_SQL + _UPSERT_TAIL, _params(user_id, f))
    return len(findings)


def replace_findings_of_kind(user_id: UUID, kind: str, findings: list[Finding]) -> int:
    """Replace ``user_id``'s findings of ``kind`` with ``findings`` (one transaction).

    Replacement (not UPSERT) so a pattern that no longer reaches significance is
    removed rather than lingering as stale advice — the cutoff-finder contract.
    """
    with tenant_transaction(user_id) as cur:
        cur.execute("DELETE FROM finding WHERE user_id = %s AND kind = %s", (user_id, kind))
        for f in findings:
            cur.execute(_INSERT_SQL, _params(user_id, f))
    return len(findings)


_SELECT_KEYS = (
    "kind",
    "description",
    "metric_a",
    "metric_b",
    "event_kind",
    "lag_days",
    "effect_size",
    "effect_metric",
    "p_value",
    "q_value",
    "n_samples",
    "research_note_ids",
)


def significant_findings(cur: Cur, user_id: UUID, limit: int = 30) -> list[dict]:
    """Read one owner's significant findings on the CALLER's cursor, largest |effect| first.

    The cursor-taking form is the one the read path must use. A read service that is
    already inside a `tenant_transaction` holds a pooled connection; if it called the
    self-opening :func:`get_significant_findings` it would borrow a SECOND connection
    while holding the first, and ~`_POOL_MAX_SIZE` concurrent requests would then all
    hold #1 and all wait for #2 — a collective stall, not a slowdown (standards §1:
    "no per-item connections — the pool is the only way in").
    """
    cur.execute(
        f"SELECT {', '.join(_SELECT_KEYS)} FROM finding "
        "WHERE user_id = %s AND significant = TRUE ORDER BY ABS(effect_size) DESC LIMIT %s",
        (user_id, limit),
    )
    return [dict(zip(_SELECT_KEYS, r, strict=True)) for r in cur.fetchall()]


def get_significant_findings(user_id: UUID, limit: int = 30) -> list[dict]:
    """:func:`significant_findings` on its own connection — for callers with no cursor.

    Job/insight-context callers only (`jobs/recs_context`, `insights/context_sessions`),
    which run outside any transaction. **Never call this from a read service that
    already holds a cursor** — pass the cursor to :func:`significant_findings` instead.
    """
    with tenant_transaction(user_id) as cur:
        return significant_findings(cur, user_id, limit)
