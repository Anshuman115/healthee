"""Smoke test — keeps pytest green from day one.

Real (if trivial) assertions: the package imports and exposes a version.
Phase 1 replaces this with seeded-DB integration and contract tests.
"""

from __future__ import annotations

import healthee


def test_package_imports_and_has_version() -> None:
    assert isinstance(healthee.__version__, str)
    assert healthee.__version__.count(".") == 2  # semver-ish major.minor.patch
