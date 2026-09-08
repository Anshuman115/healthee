"""The twelve Minetti 2002 coefficients live in two places, and they must agree.

Until 2026-09-08 they lived in exactly one: inline in
``derive/vo2max_submax.py::_vo2_speed_grade``, with **no copy anywhere in
`packages/knowledge`** (audit D11). So nothing in the repo could have caught a
transcription error in any of them — which is the pre-#108 SEE defect exactly, except on
twelve numbers instead of one, and inside the science that produces the graded VO₂max
tier. The audit checked them against the paper and found them correct *today*; that is a
snapshot, not a guard.

``submaximal_vo2max.md`` now carries the table, and this test is the correspondence: edit
the code alone and it fails; edit the note alone and it fails. The same two-ended contract
`guard_directives` uses for safety markers, applied to a polynomial.

It parses the note rather than restating the numbers a third time. A third copy would be
a third thing to keep in step, and the whole defect is copies that can drift.
"""

from __future__ import annotations

import re
from pathlib import Path

from healthee.derive.vo2max_submax import _MINETTI_CLAMP, _vo2_speed_grade

_NOTE = (
    Path(__file__).resolve().parents[4]
    / "packages"
    / "knowledge"
    / "notes"
    / "activity"
    / "submaximal_vo2max.md"
)

# The row shape written into the note's table, e.g.
# `| **Running** | 155.4 | −30.4 | −43.3 | 46.3 | 19.5 | **3.6** |`
_ROW = re.compile(
    r"\|\s*\*\*(Running|Walking)\*\*\s*\|"
    + r"\s*(−?-?[\d.]+)\s*\|" * 5
    + r"\s*\*\*(−?-?[\d.]+)\*\*\s*\|"
)


def _note_coefficients() -> dict[str, list[float]]:
    """``{"Running": [i5, i4, i3, i2, i1, i0], ...}`` as the note states them."""
    rows = _ROW.findall(_NOTE.read_text())
    assert len(rows) == 2, f"the Minetti table is not in the note as written: {rows}"
    return {row[0]: [float(value.replace("−", "-")) for value in row[1:]] for row in rows}


def _cw(coefficients: list[float], gradient: float) -> float:
    """Minetti's cost of transport at ``gradient``, from the note's own numbers."""
    i5, i4, i3, i2, i1, i0 = coefficients
    g = gradient
    return i5 * g**5 + i4 * g**4 + i3 * g**3 + i2 * g**2 + i1 * g + i0


def test_the_note_states_all_twelve_coefficients() -> None:
    """Vacuity guard: an empty or half-filled table must not pass silently."""
    note = _note_coefficients()
    assert set(note) == {"Running", "Walking"}
    assert all(len(values) == 6 for values in note.values())
    # The two level costs are the ones the ratio divides by; a zero there would make
    # every scaled VO2 infinite, so they are worth naming.
    assert note["Running"][-1] == 3.6
    assert note["Walking"][-1] == 2.5


def test_the_code_computes_the_note_s_polynomial() -> None:
    """Term for term, over the whole validated gradient range and both gait branches.

    Compared through ``_vo2_speed_grade``'s OUTPUT rather than by reaching for the
    literals: a test that re-read the same constants out of the module would pass against
    a module that had stopped using them.
    """
    note = _note_coefficients()
    for speed_ms, gait in ((3.0, "Running"), (1.4, "Walking")):
        level = 3.5 + (0.2 if gait == "Running" else 0.1) * speed_ms * 60.0
        cw0 = note[gait][-1]
        for gradient in (-0.45, -0.30, -0.10, 0.0, 0.05, 0.10, 0.25, 0.45):
            expected = level * max(_cw(note[gait], gradient), 0.7) / cw0
            actual = _vo2_speed_grade(speed_ms, gradient)
            assert abs(actual - expected) < 1e-9, (
                f"{gait} at grade {gradient}: code {actual}, note {expected} — the "
                f"coefficients in derive/vo2max_submax.py and submaximal_vo2max.md "
                f"have drifted apart"
            )


def test_level_ground_leaves_the_acsm_value_untouched() -> None:
    """A known value, hand-computed: at grade 0 the cost ratio is exactly 1.

    This is the anchor that makes the comparison above meaningful — it fixes the
    polynomial's constant term against the ACSM equation rather than only against itself.
    """
    # Running at 3 m/s = 180 m/min: 3.5 + 0.2*180 = 39.5 mL/kg/min.
    assert abs(_vo2_speed_grade(3.0, 0.0) - 39.5) < 1e-9
    # Walking at 1.4 m/s = 84 m/min: 3.5 + 0.1*84 = 11.9.
    assert abs(_vo2_speed_grade(1.4, 0.0) - 11.9) < 1e-9


def test_the_gradient_is_clamped_to_minettis_validated_range() -> None:
    """Beyond ±0.45 the polynomial is extrapolation, and the paper does not go there."""
    assert _MINETTI_CLAMP == 0.45
    assert _vo2_speed_grade(3.0, 0.9) == _vo2_speed_grade(3.0, _MINETTI_CLAMP)
    assert _vo2_speed_grade(3.0, -0.9) == _vo2_speed_grade(3.0, -_MINETTI_CLAMP)
