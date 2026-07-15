"""Generate the stats-kernel golden fixture from the LEGACY (proven) analytics.

Run MANUALLY to (re)produce ``fixtures/analytics/expected_stats.json`` — the
golden output the CI test asserts the NEW ``analytics.stats`` reproduces. It is
NOT a pytest module (underscore-prefixed, never collected) and legacy is NEVER
imported at CI time: this script imports the legacy ``healthee.analytics``
kernels, while the test imports the new ``healthee.analytics.stats`` — both share
the top-level ``healthee`` package name and so MUST run in separate processes
(hence the committed artefact rather than a live computation).

Provenance: it feeds the shared deterministic inputs (``_stats_seed.py``) to the
legacy ``_spearman_lag``, ``_mann_whitney_effect``, ``_apply_bh_fdr`` and the
cutoff finder's ``_mwu_compare``, then dumps their outputs. Usage::

    LEGACY_SRC=~/projects/healthee-legacy/src \\
    POSTGRES_PASSWORD=x REALTIME_INGEST_TOKEN=x \\
    python tests/analytics/_generate_stats_fixture.py
"""

from __future__ import annotations

import importlib
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_FIXTURE = _HERE.parent / "fixtures" / "analytics" / "expected_stats.json"


@dataclass
class _F:
    """Minimal stand-in for legacy Finding — _apply_bh_fdr only needs p/q."""

    p_value: float
    q_value: float | None = None


def main() -> None:
    legacy_src = os.environ.get("LEGACY_SRC", str(Path.home() / "projects/healthee-legacy/src"))
    sys.path.insert(0, legacy_src)
    sys.path.insert(0, str(_HERE))  # for `import _stats_seed`

    import _stats_seed as seed

    # Load the legacy modules dynamically. ``correlations`` also exists in the NEW
    # tree, so a static ``from …import`` would resolve there and fail type-check;
    # ``import_module`` (with legacy first on sys.path at run time) sidesteps that.
    corr = importlib.import_module("healthee.analytics.correlations")
    cutoff = importlib.import_module("healthee.analytics.cutoff_finder")

    spearman0 = corr._spearman_lag(seed.series_a(), seed.series_b(), 0)
    spearman1 = corr._spearman_lag(seed.series_a(), seed.series_b(), 1)
    mwu_event = corr._mann_whitney_effect(seed.metric_series(), seed.event_days(), 0)

    after = [{"o": v} for v in seed.group_treated()]
    control = [{"o": v} for v in seed.group_control()]
    mwu_groups = cutoff._mwu_compare(after, control, "o")

    findings = [_F(p) for p in seed.p_values()]
    corr._apply_bh_fdr(findings)
    bh = [f.q_value for f in findings]

    fixture = {
        "spearman_lag0": list(spearman0) if spearman0 else None,
        "spearman_lag1": list(spearman1) if spearman1 else None,
        "mann_whitney_effect": list(mwu_event) if mwu_event else None,
        "mann_whitney_groups": list(mwu_groups) if mwu_groups else None,
        "bh_fdr": bh,
    }
    _FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    _FIXTURE.write_text(json.dumps(fixture, indent=2) + "\n")
    print(f"wrote {_FIXTURE}")


if __name__ == "__main__":
    main()
