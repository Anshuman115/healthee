"""Explicit profile edits, independent of strap sync and weight freshness."""

from __future__ import annotations

from datetime import date
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from healthee.core.dob import parse_dob
from healthee.derive._common import Cur
from healthee.ingest.profile_write import PROFILE_COLUMNS, write_profile
from healthee.read.logs import LogRequest, record_log


class ProfileEdit(BaseModel):
    """Omitted fields are preserved; explicit null clears a demographic answer.

    Weight is a measurement at save time, never a restored profile default.
    """

    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    name: str | None = Field(default=None, max_length=100)
    height_cm: float | None = Field(default=None, gt=0, le=300)
    sex: Literal["male", "female"] | None = None
    dob_date: date | None = None
    srpa: int | None = Field(default=None, ge=0, le=4)
    measured_weight_kg: float | None = Field(default=None, gt=0, le=500)

    @field_validator("dob_date")
    @classmethod
    def plausible_birth_date(cls, value: date | None) -> date | None:
        if value is not None:
            parse_dob(value.isoformat(), "UTC")  # ISO calendar dates have no timezone.
        return value


class ProfileEditResult(BaseModel):
    """Acknowledgement; derived daily metrics refresh with subsequent derivation."""

    ok: bool = True


def edit_profile(cur: Cur, user_id: UUID, edit: ProfileEdit) -> ProfileEditResult:
    """One atomic, tenant-scoped edit; concurrent partial edits preserve other fields.

    The statement itself lives in `ingest/profile_write.py`, because `profile` has a
    second writer — the strap sync — and the two used to disagree about what an absent
    field means (audit B2). This one was right and the other one erased demographics, so
    the fix is one rule rather than a second careful implementation.

    `dob_date` is this model's name for the `dob` column; the translation happens here so
    the shared writer asks "was `dob` supplied" about one spelling.
    """
    supplied = edit.model_fields_set
    write_profile(
        cur,
        user_id,
        values={
            "name": edit.name,
            "height_cm": edit.height_cm,
            "sex": edit.sex,
            "dob": edit.dob_date,
            "srpa": edit.srpa,
        },
        supplied=frozenset(
            {"dob" if field == "dob_date" else field for field in supplied} & set(PROFILE_COLUMNS)
        ),
    )
    if edit.measured_weight_kg is not None:
        record_log(cur, user_id, LogRequest(type="weight", amount=edit.measured_weight_kg))
    return ProfileEditResult()
