"""The ``correlate`` chain step — recompute personal findings for the window.

A thin wrapper over the merged ``analytics`` layer: it does NOT reimplement any
statistics (standards §"Science code is sacred" — the Spearman/Mann-Whitney/FDR
kernels and the caffeine/alcohol cutoff finder live in ``analytics`` and are
ported verbatim there). It just drives the two persist paths the legacy
``healthee correlate`` command drove:

  * pairwise + event-effect findings  → ``persist_findings`` (UPSERT on the key);
  * personal caffeine/alcohol cutoffs → ``persist_cutoff_findings`` (replace).

Recs depend on these rows, which is why the chain runs this first.
"""

from __future__ import annotations

from healthee.analytics.correlations import compute_all_findings
from healthee.analytics.cutoffs import compute_cutoff_findings, persist_cutoff_findings
from healthee.analytics.finding import persist_findings
from healthee.core.logging import get_logger
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID

log = get_logger(__name__)


def run_correlate() -> dict:
    """Recompute + persist every personal finding. Returns a small status dict.

    Errors propagate to the supervised chain runner (``chain._run_supervised``),
    which logs + Telegram-notifies — this function never swallows (standards §1).
    """
    # 6.4: source the owner + tz from the authenticated user / per-user job loop.
    findings = compute_all_findings(SENTINEL_USER_ID, SENTINEL_TZ)
    n_findings = persist_findings(SENTINEL_USER_ID, findings)
    n_significant = sum(1 for f in findings if f.significant)

    cutoffs = compute_cutoff_findings(SENTINEL_USER_ID, SENTINEL_TZ)
    n_cutoffs = persist_cutoff_findings(cutoffs)

    log.info(
        "correlate: %d findings persisted (%d significant), %d cutoffs",
        n_findings,
        n_significant,
        n_cutoffs,
    )
    return {"findings": n_findings, "significant": n_significant, "cutoffs": n_cutoffs}
