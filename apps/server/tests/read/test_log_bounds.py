"""What `POST /api/log` refuses — `AUTH_AUDIT.md` D4.

`LogRequest` had `max_length` on its four strings and NOTHING on its four numbers, while
`read/gps_request.py` — a phone upload of the same trust level, one directory over —
bounded its payload to the millimetre.

The sharp one is `type: "weight"`. It wrote `float(req.amount or 0)` into
`weight_log.kg`: a `numeric(5,2)` column, so an unbounded float was a database error
before it was anything else, and the value feeds BMI, VO2max and biological age. Two
separate defects lived in that one expression and both are asserted below — the missing
range, and `or 0`, which stored **0 kg** for a weight log that forgot its number.

Model-level, because that is where the refusal is: these run without a database, and
`tests/integration` covers the endpoint end to end.
"""

from __future__ import annotations

import json
import math
from uuid import UUID

import pytest
from pydantic import ValidationError

from healthee.core.bounds import MAX_WEIGHT_KG, MIN_WEIGHT_KG, MeasurementError
from healthee.read.logs import LogRequest, record_log

_NOW_MS = 1_780_000_000_000  # 2026-06-08
_USER = UUID("00000000-0000-0000-0000-0000000000aa")


class _RefusingCursor:
    """A cursor that fails the test if anything reaches the database.

    The claim under test is that the value is refused BEFORE a row is written; a mock
    that silently accepted the INSERT would let a "rejected" test pass while the row
    landed.
    """

    def execute(self, *_args: object, **_kwargs: object) -> None:
        raise AssertionError("a refused log reached the database")

    def fetchone(self) -> None:
        raise AssertionError("a refused log reached the database")


def _cur() -> object:
    return _RefusingCursor()


# ── the numbers are bounded ──────────────────────────────────────────────────


@pytest.mark.parametrize("literal", ["NaN", "Infinity", "-Infinity"])
def test_a_non_numeric_amount_is_refused(literal: str) -> None:
    body = json.loads(f'{{"type": "water", "amount": {literal}}}')
    assert math.isnan(body["amount"]) or math.isinf(body["amount"])
    with pytest.raises(ValidationError):
        LogRequest.model_validate(body)


def test_an_absurd_amount_is_refused() -> None:
    with pytest.raises(ValidationError):
        LogRequest.model_validate({"type": "water", "amount": 1e308})


def test_an_out_of_range_at_is_refused() -> None:
    """`record_log` did `datetime.fromtimestamp(req.at / 1000, tz=UTC)` — the same
    unbounded conversion D2 names, one router over."""
    for at in (10**18, -(10**18), 99_999_999_999_999):
        with pytest.raises(ValidationError):
            LogRequest.model_validate({"type": "water", "amount": 250, "at": at})


def test_an_absurd_minutes_is_refused() -> None:
    """`ts - timedelta(minutes=mins)` raises `OverflowError` — a 500 for a client's
    number — on a large enough value."""
    for minutes in (10**12, -1):
        with pytest.raises(ValidationError):
            LogRequest.model_validate({"type": "meditation", "minutes": minutes})


def test_a_normal_log_is_still_accepted() -> None:
    req = LogRequest.model_validate(
        {"type": "caffeine", "amount": 80, "unit": "mg", "at": _NOW_MS, "notes": "espresso"}
    )
    assert req.amount == 80
    assert LogRequest.model_validate({"type": "meditation", "minutes": 20}).minutes == 20


# ── the weight is a body mass ────────────────────────────────────────────────


@pytest.mark.parametrize("kg", [0.0, MIN_WEIGHT_KG - 0.1, MAX_WEIGHT_KG + 0.1, 999.0])
def test_a_weight_outside_human_range_never_reaches_the_table(kg: float) -> None:
    req = LogRequest.model_validate({"type": "weight", "amount": kg})
    with pytest.raises(MeasurementError):
        record_log(_cur(), _USER, req)  # type: ignore[arg-type]


def test_a_weight_log_with_no_amount_is_refused_rather_than_stored_as_zero() -> None:
    """`float(req.amount or 0)` stored 0 kg for a body-mass log that forgot its number.

    That is worse than a rejection in the way this product cares about: the row is fresh,
    so `derive.freshness` cannot withhold on staleness, and 0 kg then feeds BMI, VO2max
    and biological age as though somebody had stood on a scale.
    """
    req = LogRequest.model_validate({"type": "weight"})
    assert req.amount is None
    result = record_log(_cur(), _USER, req)  # type: ignore[arg-type]
    assert result["ok"] is False
    assert "kilograms" in str(result["error"])


def test_a_real_weight_is_accepted_by_the_model() -> None:
    assert LogRequest.model_validate({"type": "weight", "amount": 79.9}).amount == 79.9
