"""Generate the derive parity fixture from the LEGACY (proven) science layer.

Run MANUALLY to (re)produce ``fixtures/derive/expected_daily.json`` — the golden
output the CI test asserts the NEW derive package reproduces. It is NOT a pytest
module (underscore-prefixed, never collected) and legacy is NEVER imported at CI
time: this script imports ``healthee.v2.derive`` from the legacy tree, while the
test imports the new ``healthee.derive`` — the two share the top-level ``healthee``
package name and so MUST run in separate processes (this is why the fixture is a
committed artefact, not computed live).

Provenance: it seeds the shared deterministic dataset (``_seed.py``), runs the
legacy ``derive_night`` for every night then ``derive_day`` for every day against a
throwaway TimescaleDB, and dumps ``derived_daily``. Usage::

    LEGACY_SRC=~/projects/healthee-legacy/src \\
    POSTGRES_HOST=localhost POSTGRES_PORT=5546 POSTGRES_DB=healthee \\
    POSTGRES_USER=healthee POSTGRES_PASSWORD=... REALTIME_INGEST_TOKEN=x \\
    python tests/derive/_generate_fixtures.py
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import psycopg

_HERE = Path(__file__).resolve().parent
_FIXTURE = _HERE.parent / "fixtures" / "derive" / "expected_daily.json"


def _dump_daily(cur) -> list[dict]:
    cur.execute("SELECT day, metric, value, flags FROM derived_daily ORDER BY day, metric")
    return [
        {"day": row[0].isoformat(), "metric": row[1], "value": row[2], "flags": row[3]}
        for row in cur.fetchall()
    ]


def main() -> None:
    legacy_src = os.environ.get("LEGACY_SRC", str(Path.home() / "projects/healthee-legacy/src"))
    sys.path.insert(0, legacy_src)
    sys.path.insert(0, str(_HERE))  # for `import _seed`

    import _seed  # the shared deterministic dataset (stdlib-only)

    # The legacy tree is only importable at manual-run time (env LEGACY_SRC on the
    # path); it is never present in CI, hence the type-checker/linter suppressions.
    import healthee.v2.derive as legacy  # type: ignore[import-not-found]  # noqa: E402

    conninfo = (
        f"host={os.environ['POSTGRES_HOST']} port={os.environ['POSTGRES_PORT']} "
        f"dbname={os.environ['POSTGRES_DB']} user={os.environ['POSTGRES_USER']} "
        f"password={os.environ['POSTGRES_PASSWORD']}"
    )
    with psycopg.connect(conninfo, autocommit=True) as conn, conn.cursor() as cur:
        _seed.seed(cur)
        for start, end in _seed.nights():
            legacy.derive_night(cur, start, end)
        for day in _seed.DAYS:
            legacy.derive_day(cur, day)
        rows = _dump_daily(cur)

    _FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    _FIXTURE.write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n")
    print(f"wrote {len(rows)} rows -> {_FIXTURE}")


if __name__ == "__main__":
    main()
