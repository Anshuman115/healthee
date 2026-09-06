"""Explicit profile edits, independent of strap sync and weight freshness."""

from __future__ import annotations

from datetime import date
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from healthee.core.dob import parse_dob
from healthee.derive._common import Cur
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
    """One atomic, tenant-scoped edit; concurrent partial edits preserve other fields."""
    supplied = edit.model_fields_set
    cur.execute(
        "INSERT INTO profile (user_id, name, height_cm, sex, dob, srpa, updated_at) "
        "VALUES (%s, %s, %s, %s, %s, %s, now()) "
        "ON CONFLICT (user_id) DO UPDATE SET "
        "name = CASE WHEN %s THEN EXCLUDED.name ELSE profile.name END, "
        "height_cm = CASE WHEN %s THEN EXCLUDED.height_cm ELSE profile.height_cm END, "
        "sex = CASE WHEN %s THEN EXCLUDED.sex ELSE profile.sex END, "
        "dob = CASE WHEN %s THEN EXCLUDED.dob ELSE profile.dob END, "
        "srpa = CASE WHEN %s THEN EXCLUDED.srpa ELSE profile.srpa END, updated_at = now()",
        (
            user_id,
            edit.name,
            edit.height_cm,
            edit.sex,
            edit.dob_date,
            edit.srpa,
            "name" in supplied,
            "height_cm" in supplied,
            "sex" in supplied,
            "dob_date" in supplied,
            "srpa" in supplied,
        ),
    )
    if edit.measured_weight_kg is not None:
        record_log(cur, user_id, LogRequest(type="weight", amount=edit.measured_weight_kg))
    return ProfileEditResult()
