"""Known-value tests for the ONE canonical robust-dispersion maths (``derive/robust``).

The expected numbers here are derived from the MATHEMATICAL DEFINITION of the
constant, not recorded from the implementation (a "known-value" test whose values
came out of the code only proves the code equals itself).

``MAD_TO_SD`` is the normal-consistency constant::

    for X ~ N(mu, sigma):  MAD = sigma * Phi^-1(0.75)
    therefore              sigma = MAD / Phi^-1(0.75) = MAD * 1.4826...

``test_mad_to_sd_is_the_normal_consistency_constant`` recomputes 1/Phi^-1(0.75) from
``statistics.NormalDist`` — an independent source — and checks the module's literal
against it. That is the whole justification for the number; it is a statistical
identity, NOT a research claim, which is why it carries no knowledge citation.
"""

from __future__ import annotations

import ast
from pathlib import Path
from statistics import NormalDist

import pytest

from healthee.derive.robust import MAD_TO_SD, robust_sd

_SRC = Path(__file__).resolve().parents[2] / "src" / "healthee"


def test_mad_to_sd_is_the_normal_consistency_constant() -> None:
    """1.4826 == 1/Phi^-1(0.75), to the 4dp the literal is written at.

    Phi^-1(0.75) = 0.6744897501960817 -> 1/0.6744897501960817 = 1.4826022185056018,
    which rounds to 1.4826. Computed here from NormalDist, never from our own code.
    """
    exact = 1.0 / NormalDist().inv_cdf(0.75)
    assert exact == pytest.approx(1.4826022185056018, abs=1e-12)
    assert round(exact, 4) == MAD_TO_SD


def test_robust_sd_scales_the_mad() -> None:
    """MAD 10 -> sigma = 10 * 1.4826 = 14.826. Unfloored by default."""
    assert robust_sd(10.0) == pytest.approx(14.826, abs=1e-9)
    assert robust_sd(0.0) == 0.0  # a flat history converts to 0, not an error


def test_robust_sd_floor_guards_a_degenerate_history() -> None:
    """The floor binds only BELOW itself; it never inflates a real spread.

    MAD 0.1 -> 0.14826, which is under a 0.5 floor -> 0.5.
    MAD 10  -> 14.826, far above it -> untouched.
    """
    assert robust_sd(0.1, floor=0.5) == 0.5
    assert robust_sd(0.0, floor=0.5) == 0.5
    assert robust_sd(10.0, floor=0.5) == pytest.approx(14.826, abs=1e-9)
    # The floor is exactly the crossover: MAD * 1.4826 == floor -> the floor is a no-op.
    assert robust_sd(0.5 / MAD_TO_SD, floor=0.5) == pytest.approx(0.5, abs=1e-12)


def _literal_1_4826_sites() -> list[str]:
    """Every module holding a `1.4826` numeric literal, as a path relative to src."""
    hits: list[str] = []
    for path in sorted(_SRC.rglob("*.py")):
        tree = ast.parse(path.read_text(), filename=str(path))
        for node in ast.walk(tree):
            if isinstance(node, ast.Constant) and node.value == 1.4826:
                hits.append(str(path.relative_to(_SRC)))
    return hits


def test_the_mad_constant_has_exactly_one_definition() -> None:
    """1.4826 is written ONCE in the tree — in ``derive/robust.py``.

    It lived in THREE modules (analytics/metrics.py, read/recovery.py,
    derive/recovery.py). Three copies of a constant is three chances for a z-score to
    mean two different things on two different screens (standards: "second occurrence
    = extract"; CLAUDE.md: "ONE canonical definition per metric").

    An AST scan, not a grep: a `1.4826` inside a docstring or comment is prose and
    must not trip this, while a re-typed literal in code must.
    """
    assert _literal_1_4826_sites() == ["derive/robust.py"]
