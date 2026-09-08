"""Golden parity: the NEW derive package reproduces the LEGACY science exactly.

Seeds the shared deterministic dataset (``_seed.py``) into a real TimescaleDB, runs
the new ``derive_night`` for every night then ``derive_day`` for every day, and
asserts the resulting ``derived_daily`` rows match ``fixtures/derive/expected_daily.json``
metric-for-metric, value-for-value, flag-for-flag.

How the fixture was obtained: ``tests/derive/_generate_fixtures.py`` seeds the SAME
dataset and runs the LEGACY ``healthee.v2.derive`` (the proven, accuracy-gated
science) against a throwaway DB, dumping ``derived_daily``. Legacy is never imported
here — the committed JSON stands in for it, so CI proves the port is numerically
identical without depending on the legacy tree.

Auto-skips when no TimescaleDB is reachable (laptop); runs in CI against the service
container.

DOCUMENTED DIVERGENCES FROM LEGACY (the fixture was re-baselined for these — every
other row is byte-identical to legacy):

  C1  vo2max_estimate.value — legacy used a biased-low, mis-transcribed Jurca
      equation (a median 40yo male scored ~24 ml/kg/min). Corrected to the
      primary-source Jurca 2005 CRF-in-METs form (×3.5 → ml/kg/min), so the six
      vo2max_estimate rows now read ~51-55 instead of ~24-26.
  M1  vo2max_estimate.flags — the `pa_score` (0-7) flag is replaced by `srpa`
      (0-4), the self-reported-PA category fed to Jurca. Since #108 it is READ FROM
      THE PROFILE (the owner's own answer), not rolled up from cadence: `_seed.py`
      seeds SR-PA-2 and the fixture carries it on every row.
  C3  vo2max_estimate.value — #108, two corrections in one re-baseline. (a) SR-PA
      enters DUMMY-CODED (Jurca 2005 Table 5, NASA column: 0 / 0.32 / 1.06 / 1.76 /
      3.03 METs); we were adding the category NUMBER, over-crediting by up to 1.27
      METs. (b) The category itself is now the profile's, not one synthesised from
      step cadence — a crosswalk nobody published, between a device signal and a
      question about deliberate exercise. Hand-derived for the seeded owner:
        BMI = 72.0 / 1.75² = 23.5102041
        CRF = 18.07 + 2.77 − 0.10×36 − 0.17×23.5102041 − 0.03×rhr + 1.06
            = 14.3032653 − 0.03×rhr METs,  VO₂ = CRF × 3.5
        rhr 55.0 → 44.2864 · 55.5 → 44.2339 · 56.0 → 44.1814
      (was ~51-55 under the linear coding with a cadence-derived category 3/4).
  M2  vo2max_estimate.flags.see_ml_kg_min — 5.6 → 5.075. The old figure appears
      nowhere in Jurca 2005; the NASA model's published SEE is 1.45 METs (Table 5).
  M3  vo2max_estimate.flags.method — a new flag, `jurca_non_exercise` on every row
      (#117). `vo2max_estimate` is now the tiered metric its three notes always
      specified, so each row names the instrument that produced it. The VALUES are
      untouched here: the seeded dataset contains no GPS track, so the measured
      tiers cannot fire and the fallback model writes every row exactly as before —
      which is the property this divergence is worth stating rather than hiding.
  M4  steps_total.flags / distance_m_daily.flags — a new `source` flag on every row
      (#121), `steps_per_minute` here. `steps_total` is now a tiered metric: the
      strap's own daily counter when it reported one, this per-minute sum otherwise.
      The seeded dataset has no `device_daily_total` row, so the fallback tier writes
      every row exactly as legacy did and NO VALUE MOVES — the flag simply says which
      instrument spoke, which is what the old shape could not say. (Legacy did not
      need to: it recomputed this cell from the per-minute sum and then let ingest
      paste the strap's counter over the top, which is the defect #121 closes.)
  M5  total_calories / active_calories / basal_calories .flags — four new stamps on
      every row (#127): `weight_kg`, `weight_as_of`, `weight_age_days` and `caveats`.
      All three metrics rest on a Mifflin-St Jeor BMR whose mass is the owner's last
      logged weight, and legacy stamped nothing about which weight or how old — the
      stale-as-current class #85 closed for BMI and missed here. NO VALUE MOVES and no
      other metric's flags change (verified row-by-row at the re-baseline): the weight
      is CAVEATED past `freshness.WEIGHT_MAX_AGE_DAYS`, never withheld and never
      substituted, so the science is byte-identical to legacy and only the provenance is
      new. The seed's weight is logged 1-8 days before the derived days, so `caveats` is
      `[]` on every fixture row — the gate's own behaviour is pinned in
      `test_calorie_weight_staleness.py`, which is where a fixture cannot reach.
  C2  sleep efficiency — the formula changed to tst/(tst+wake) (≤100% by
      construction) but the seed's tst+wake (480) equals its wall-clock span (480),
      so efficiency_pct stays 95.8 and NO sleep row moves. Verified: zero sleep
      diffs here — the correction only bites when staged minutes overshoot the span.
  C4  mvpa_min.value — 25.0 → 30.0 on all eight days (audit C2, 2026-09-08). Legacy
      stored `moderate + vigorous`; the metric is the WHO MET-EQUIVALENT total
      `moderate + 2 x vigorous`, which is what its three notes specify five times over
      and what the 150 target it is measured against is denominated in. The seed is
      20 moderate + 5 vigorous every day, so 25 → 30 on every row and the arithmetic is
      checkable by eye. FLAGS ARE UNTOUCHED — `moderate` and `vigorous` stay the raw
      halves, because the weekly card's subline reads "moderate {m} + vigorous {v} x 2"
      and needs the pair un-weighted.
      This is the one divergence that makes a number BIGGER, and that is worth stating:
      the old value under-credited vigorous minutes by half, so the correction moves
      the owner's number up. It is not flattery — it is the guideline's own equivalence,
      and it can only move a day on which vigorous minutes were recorded. This owner has
      none, which is why the audit banded it C. `test_mvpa_met_equivalent.py` is the
      known-value test that pins it where a fixture cannot reach.
  M6  sleep_*.flags.session_source — the legacy cloud's name → `strap_ble` on all six
      rows a night produces (write-path audit C1, 2026-09-08). A PROVENANCE label and
      nothing else: **no value moves and no other flag changes**, which is exactly why
      it appears here as a re-baseline rather than as a science divergence. Legacy's
      literal was true of legacy — sleep really did arrive from Zepp Cloud there. In
      this repo the only writer of the sleep session table is the strap BLE push, so
      the field named an instrument that did not take the reading. The one-writer
      premise the rename rests on is asserted, not assumed, in
      `test_session_source.py`.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.derive import derive_day, derive_night

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _seed  # noqa: E402 — shared deterministic dataset (stdlib-only)

pytestmark = pytest.mark.integration

_FIXTURE = Path(__file__).resolve().parent.parent / "fixtures" / "derive" / "expected_daily.json"
_TOL = 1e-9  # values are round()ed to 4dp by the upsert, so this is effectively exact


def _load_expected() -> dict[tuple[str, str], dict]:
    rows = json.loads(_FIXTURE.read_text())
    return {(r["day"], r["metric"]): r for r in rows}


def _dump_actual(cur) -> dict[tuple[str, str], dict]:
    cur.execute("SELECT day, metric, value, flags FROM derived_daily ORDER BY day, metric")
    return {
        (row[0].isoformat(), row[1]): {"value": row[2], "flags": row[3]} for row in cur.fetchall()
    }


def _num_eq(a: object, b: object) -> bool:
    return isinstance(a, int | float) and isinstance(b, int | float) and abs(a - b) <= _TOL


def _deep_eq(a: object, b: object) -> bool:
    """Structural equality with a float tolerance on leaf numbers."""
    if _num_eq(a, b):
        return True
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(_deep_eq(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(_deep_eq(x, y) for x, y in zip(a, b, strict=True))
    return a == b


def _derive_all(cur) -> None:
    _seed.seed(cur)
    for start, end in _seed.nights():
        derive_night(cur, SENTINEL_USER_ID, SENTINEL_TZ, start, end)
    for day in _seed.DAYS:
        derive_day(cur, SENTINEL_USER_ID, SENTINEL_TZ, day)


def test_derive_matches_legacy_golden(db: None) -> None:  # noqa: ARG001 — DB gate
    migrate.apply_migrations()
    expected = _load_expected()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _derive_all(cur)
        actual = _dump_actual(cur)

    assert actual.keys() == expected.keys(), (
        f"metric set differs: only-new={actual.keys() - expected.keys()} "
        f"only-legacy={expected.keys() - actual.keys()}"
    )
    mismatches = []
    for key, exp in expected.items():
        act = actual[key]
        if not _num_eq(act["value"], exp["value"]) or not _deep_eq(act["flags"], exp["flags"]):
            mismatches.append((key, exp, act))
    assert not mismatches, "derived rows differ from legacy:\n" + "\n".join(
        f"  {k}: legacy={e} new={a}" for k, e, a in mismatches[:10]
    )
