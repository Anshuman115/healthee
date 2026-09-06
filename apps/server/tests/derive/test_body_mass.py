"""The shared BMI arithmetic is the exact expression used by Jurca."""

from healthee.derive.body_mass import body_mass_index


def test_known_value() -> None:
    assert body_mass_index(80, 200) == 20
    assert body_mass_index(72.5, 176) == 72.5 / ((176 / 100) ** 2)
