"""The personal-cutoff finding must name the OWNER's timezone (task #31).

`_cutoff_finding` rendered the literal string "IST" into a user-facing finding
description. `h` is an hour-of-day bucketed with the owner's own zone
(`_load_substance_events` binds `AT TIME ZONE tz`), so the label was correct only
for the sentinel owner and silently wrong for everyone else — a finding
description asserting a clock the number does not belong to.

Pure unit tests: no DB, no stats — the label is the whole subject.
"""

from __future__ import annotations

import pytest

from healthee.analytics.cutoffs import CAFFEINE_EXPECTED, SUBSTANCE_CONFIG, _cutoff_finding


def _finding(tz: str):
    """One caffeine/tst_min cutoff at 22:00 for an owner in ``tz``."""
    return _cutoff_finding(
        "caffeine",
        "tst_min",
        tz,
        22,
        -0.5,
        0.01,
        12,
        18,
        320.0,
        400.0,
        CAFFEINE_EXPECTED["tst_min"],
        SUBSTANCE_CONFIG["caffeine"],
    )


@pytest.mark.parametrize(
    "tz", ["Asia/Kolkata", "America/New_York", "Europe/Dublin", "Pacific/Auckland"]
)
def test_description_names_the_owners_timezone(tz: str) -> None:
    """The zone in the copy is the zone the cutoff hour was measured in."""
    assert f"22:00 {tz}" in _finding(tz).description


def test_a_non_indian_owner_is_never_labelled_ist() -> None:
    """The exact regression: "IST" was hardcoded, so every owner read as Indian.

    `Europe/Dublin` is the sharpest case — "IST" is a real abbreviation there
    (Irish Standard Time) as well as in India, so an abbreviation-based label
    would look plausible while meaning a different clock. The IANA name cannot be
    ambiguous that way.
    """
    assert "IST" not in _finding("Europe/Dublin").description


def test_owners_in_different_zones_get_different_descriptions() -> None:
    """Same measured effect, different owners ⇒ the copy must distinguish them."""
    assert _finding("Asia/Kolkata").description != _finding("America/New_York").description


def test_the_zone_is_also_machine_readable_on_the_finding() -> None:
    """`details.cutoff_tz` pairs the hour with its zone for any non-prose consumer."""
    f = _finding("America/New_York")
    assert (f.details["cutoff_hour"], f.details["cutoff_tz"]) == (22, "America/New_York")
