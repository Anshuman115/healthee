"""The illness-flag producer against a real database: what it writes, and when it won't.

`test_illness_rule.py` pins the arithmetic with no DB in sight. This file pins the half
that arithmetic cannot reach — the two input READS (a `derived_daily` metric and a
skin-temp average over the sleep window), the freshness gate, the write, the clear, and
tenant isolation.

Auto-skips without a reachable TimescaleDB (same policy as the other integration tests).
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import timedelta

import pytest
from tests.derive import _illness_seed as seed

from healthee.core.db import tenant_transaction
from healthee.derive.freshness import NOT_DERIVED_YET
from healthee.derive.illness import INSUFFICIENT_BASELINE, derive_illness_flag

pytestmark = [
    pytest.mark.integration,
    # Owners are provisioned here (explicitly, or JIT on the first authenticated
    # request) and were never removed — 7 stray `app_user` rows per run, ~1,288 on a
    # box that had been in use. `--user`-less ops tooling walks every one (#119).
    pytest.mark.usefixtures("owner_sweep"),
]

NIGHT = seed.NIGHT


@pytest.fixture
def owners(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    seed.reset()
    seed.ensure_owner_b()
    yield
    seed.reset()


def _run(user_id=seed.OWNER, night=NIGHT) -> dict:
    with tenant_transaction(user_id) as cur:
        return derive_illness_flag(cur, user_id, seed.TZ, night)


def _stored(user_id=seed.OWNER, night=NIGHT) -> tuple | None:
    with tenant_transaction(user_id) as cur:
        return seed.stored_flag(cur, user_id, night)


def _seed_owner(user_id=seed.OWNER, *, ill: bool = False, ill_nights: int = 1) -> None:
    """A steady history, optionally with the last ``ill_nights`` nights elevated."""
    with tenant_transaction(user_id) as cur:
        seed.steady_history(cur, user_id)
        for back in range(ill_nights) if ill else ():
            seed.write_night(
                cur, user_id, NIGHT - timedelta(days=back), rr=seed.ILL_RR, temp_c=seed.ILL_TEMP
            )


# ── the known-value pass: an owner who deviates, and one who doesn't ──────────


def test_an_owner_whose_vitals_deviate_gets_a_flag_with_the_notes_numbers(
    owners: None,  # noqa: ARG001
) -> None:
    """The end of the defect: a real row, written by the code, with auditable deltas.

    Hand-checked against [[illness_flag_plan]]: the 14-night RR median is 13.5 and the
    night is 16.0, so ``rr_delta`` is +2.5; the temperature median is 33.25 and the
    night is 34.0, so ``temp_delta`` is +0.75. One elevated night is not sustained, so
    the tier is the note's Moderate, not High.
    """
    _seed_owner(ill=True)
    result = _run()

    assert result["severity"] == "moderate"
    assert result["rr_delta_bpm"] == pytest.approx(2.5)
    assert result["temp_delta_c"] == pytest.approx(0.75)

    row = _stored()
    assert row is not None
    severity, rr_delta, temp_delta, sustained, notes = row
    assert severity == "moderate"
    assert rr_delta == pytest.approx(2.5) and temp_delta == pytest.approx(0.75)
    assert sustained is False
    assert notes == ["respiratory_rate_normal", "skin_temp_signals"]


def test_an_owner_whose_vitals_are_steady_gets_nothing(owners: None) -> None:  # noqa: ARG001
    """Sixteen ordinary nights must produce no row at all — a flag that fires on a
    normal week is worse than no flag, because it teaches the owner to ignore it."""
    _seed_owner()
    assert _run()["severity"] is None
    assert _stored() is None


def test_sustained_fires_only_on_persistence_and_raises_the_tier(owners: None) -> None:  # noqa: ARG001
    """[[illness_flag_plan]]: High = both limbs AND night N-1 also over +1.5 br/min.

    The same night, judged twice: elevated alone it is Moderate and not sustained;
    elevated with the night before it, it is High and sustained. That is the whole
    Smarr-2020 / Quer-2021 two-night convention, and it is the only difference between
    the two halves of this test.
    """
    _seed_owner(ill=True, ill_nights=1)
    assert _run()["sustained"] is False
    single = _stored()
    assert single is not None and single[0] == "moderate"

    _seed_owner(ill=True, ill_nights=2)
    result = _run()
    assert result["sustained"] is True
    assert result["severity"] == "high"
    repeated = _stored()
    assert repeated is not None and repeated[3] is True


# ── auto-clear ───────────────────────────────────────────────────────────────


def test_the_flag_auto_clears_when_the_deltas_fall_back(owners: None) -> None:  # noqa: ARG001
    """Coach Directive 5: "auto-clear when deltas fall below the moderate thresholds".

    A stored row that no longer follows from the data must not survive because it was
    once true — an owner who recovered would otherwise stay flagged, and their training
    levers stay withheld, for as long as nobody overwrote the row.
    """
    _seed_owner(ill=True)
    assert _stored() is None
    _run()
    assert _stored() is not None

    with tenant_transaction(seed.OWNER) as cur:  # the night re-reads as ordinary
        seed.write_night(cur, seed.OWNER, NIGHT, rr=seed.HEALTHY_RR[0], temp_c=seed.HEALTHY_TEMP[0])
    result = _run()

    assert result["cleared"] is True
    assert result["severity"] is None
    assert _stored() is None


def test_clearing_a_night_that_never_had_a_flag_is_not_reported_as_a_clear(
    owners: None,  # noqa: ARG001
) -> None:
    """ "Nothing to clear" and "a flag went away" are different facts (standards §Errors)."""
    _seed_owner()
    assert _run()["cleared"] is False


# ── the freshness gate: a flag is a claim about ONE night ────────────────────


def test_a_night_with_no_inputs_of_its_own_produces_nothing_and_says_why(
    owners: None,  # noqa: ARG001
) -> None:
    """The stale-as-current class, refused at the producer.

    The owner's history is ill right up to the night before, so every input needed to
    "conclude" something about ``NIGHT`` exists — except ``NIGHT``'s own. Borrowing the
    neighbour is exactly the bug ``derive/freshness.py`` was extracted to kill, so the
    answer is the shared ``NOT_DERIVED_YET``, and no row.
    """
    with tenant_transaction(seed.OWNER) as cur:
        seed.steady_history(cur, seed.OWNER, last_night=NIGHT - timedelta(days=1), nights=16)
        seed.write_night(
            cur, seed.OWNER, NIGHT - timedelta(days=1), rr=seed.ILL_RR, temp_c=seed.ILL_TEMP
        )

    result = _run()

    assert result["skipped"] == NOT_DERIVED_YET
    assert result["severity"] is None
    assert _stored() is None


def test_too_little_history_is_named_apart_from_a_missing_night(owners: None) -> None:  # noqa: ARG001
    """ "We cannot judge yet" is not "we have no input" — the job surface must tell them
    apart, and [[illness_flag_plan]] Coach Directive 1 requires the silent skip either
    way. Nine baseline nights is one short of the note's ten."""
    with tenant_transaction(seed.OWNER) as cur:
        seed.steady_history(cur, seed.OWNER, nights=9)
        seed.write_night(cur, seed.OWNER, NIGHT, rr=seed.ILL_RR, temp_c=seed.ILL_TEMP)

    assert _run()["skipped"] == INSUFFICIENT_BASELINE
    assert _stored() is None


def test_the_strong_limb_still_fires_for_an_owner_with_no_skin_temperature(
    owners: None,  # noqa: ARG001
) -> None:
    """The per-limb sufficiency reading, end to end.

    A strap that never reports usable skin temperature must not cost the owner the
    strong, CITED respiratory-rate limb — that would be a safety rule with a dead input,
    which is the defect this module was written to end. The stored citations name only
    the limb that actually spoke: a chip for a signal we could not measure is a fake
    citation.
    """
    with tenant_transaction(seed.OWNER) as cur:
        seed.steady_history(cur, seed.OWNER, temp=False)
        seed.write_night(cur, seed.OWNER, NIGHT, rr=seed.ILL_RR, temp_c=None)

    assert _run()["severity"] == "moderate"
    row = _stored()
    assert row is not None
    severity, rr_delta, temp_delta, _sustained, notes = row
    assert (severity, temp_delta) == ("moderate", None)
    assert rr_delta == pytest.approx(2.5)
    assert notes == ["respiratory_rate_normal"]


def test_a_daytime_nap_is_not_part_of_the_overnight_temperature(owners: None) -> None:  # noqa: ARG001
    """Only ``kind='main'`` counts — a hot afternoon nap is not an illness signal.

    [[skin_temp_signals]] is unambiguous that daytime wrist readings are "useless for
    fever/illness detection" (ambient and postural noise swamps the signal), and the
    trustworthy reading is the OVERNIGHT deviation. A nap session sits inside the same
    local day and would be averaged straight into the night's mean if the session filter
    were dropped — turning a warm room at 15:00 into a +5 °C "early illness signal".
    """
    with tenant_transaction(seed.OWNER) as cur:
        seed.steady_history(cur, seed.OWNER)
        cur.execute(
            "INSERT INTO sleep_session (user_id, start_ts, end_ts, kind) "
            "VALUES (%s, %s, %s, 'nap')",
            (seed.OWNER, "2026-05-20 14:00+05:30", "2026-05-20 15:00+05:30"),
        )
        cur.execute(
            "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s)",
            (seed.OWNER, "2026-05-20 14:30+05:30", "skin_temp_c", 38.0),
        )

    result = _run()

    assert result["severity"] is None
    assert _stored() is None


def test_daytime_skin_temperature_is_never_read(owners: None) -> None:  # noqa: ARG001
    """[[skin_temp_signals]]: daytime wrist readings are "useless for fever/illness
    detection". A hot afternoon must not become an illness signal, so the temp limb
    reads only samples inside the sleep window — an owner with nothing but daytime
    samples has no temp limb at all, and their RR limb decides alone."""
    with tenant_transaction(seed.OWNER) as cur:
        seed.steady_history(cur, seed.OWNER, temp=False)
        seed.write_night(cur, seed.OWNER, NIGHT, rr=seed.ILL_RR, temp_c=None)
        cur.execute(
            "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, %s, %s)",
            (seed.OWNER, "2026-05-20 14:00+05:30", "skin_temp_c", 38.0),
        )

    assert _run()["temp_delta_c"] is None


# ── isolation ────────────────────────────────────────────────────────────────


def test_one_owners_illness_never_reaches_another(owners: None) -> None:  # noqa: ARG001
    """Owner A is ill on the same night owner B is fine, from identical-shaped data.

    Both directions are asserted, because a producer that leaked would most likely leak
    by reading the wrong owner's baseline — which shows up as B being flagged, not as A
    losing anything.
    """
    _seed_owner(seed.OWNER, ill=True)
    _seed_owner(seed.OTHER_OWNER)

    assert _run(seed.OWNER)["severity"] == "moderate"
    assert _run(seed.OTHER_OWNER)["severity"] is None

    assert _stored(seed.OWNER) is not None
    assert _stored(seed.OTHER_OWNER) is None


def test_a_second_owners_nights_do_not_pollute_the_first_ones_baseline(
    owners: None,  # noqa: ARG001
) -> None:
    """Owner B's history is wildly elevated; owner A's baseline must not move.

    If the baseline query lost its owner predicate, A's median would climb toward B's
    and A's genuinely ill night would stop looking ill — a leak that HIDES a safety
    signal rather than exposing data, and so one no payload test would catch.
    """
    _seed_owner(seed.OWNER, ill=True)
    with tenant_transaction(seed.OTHER_OWNER) as cur:
        for index in range(16):
            seed.write_night(
                cur, seed.OTHER_OWNER, NIGHT - timedelta(days=index), rr=30.0, temp_c=39.0
            )

    result = _run(seed.OWNER)
    assert result["severity"] == "moderate"
    assert result["rr_delta_bpm"] == pytest.approx(2.5)
