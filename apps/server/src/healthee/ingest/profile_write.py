"""The ONE rule for writing the profile table, and the one statement that applies it.

## Why this module exists (write-path audit B2)

`profile` had two writers with two different answers to "what does an absent field
mean". `read/profile_edit.edit_profile` resolved each field against `model_fields_set`
— *"Omitted fields are preserved; explicit null clears a demographic answer"* — while
`ingest/upsert.upsert_profile` COALESCEd `name` and `srpa` and plainly ASSIGNED
`height_cm`, `sex` and `dob`. So a sync whose `profile` block omitted a demographic
**erased it**, and the docstring one screen up said the opposite of what the SQL did:
*"the server upserts whatever is present"*. It upserted what was present and nulled
what was not.

The blast radius is the profile-dependent half of the derive layer: `_load_profile`
returns `None` when any of height/sex/dob is missing, which takes out calories,
distance, cardio load and the Jurca tier, and `_date_of_birth` takes out sleep need and
sleep debt. **`profile` has no history table — nothing anywhere else holds the owner's
date of birth**, so that erasure is not recoverable by a re-derive.

It was latent rather than live (the v02 client sends no profile at all; the legacy app
sends one only when complete), and it is fixed anyway for the reason the sleep-COALESCE
defect was: `/ingest/helio` is reachable by any device token, including an older app
build nobody here can inspect.

## The rule, stated once

**Omitted is preserved. Explicit null clears.** Those are different facts and the wire
can express both, so the writer must not collapse them. A COALESCE cannot — it reads
both as "keep" — which is why this is a `CASE WHEN <supplied>` per column rather than
the COALESCE that protected two of the five fields.

`srpa` moves under the same rule and that is a deliberate, priced change: it was
COALESCEd because *"every existing client builds this payload without the field, so a
plain assignment would let the next routine sync NULL out an answer the owner had
given"*. Omission still preserves it — that argument is fully honoured — and an
explicit null now clears it, which is the only way the profile editor's "clear this
answer" can reach the same column through the same rule. One table, one rule.
"""

from __future__ import annotations

from datetime import date
from typing import LiteralString, cast
from uuid import UUID

from psycopg import Cursor
from psycopg.rows import TupleRow

Cur = Cursor[TupleRow]

# The columns this statement writes, in the order it binds them. `updated_at` is not
# here: it is `now()` on both branches and is never something a caller supplies.
#
# NOT a superset of what a caller happens to send — it is the canonical spelling both
# writers translate INTO, so `ProfileEdit.dob_date` and `ProfileIn.dob` name the same
# column here and the "was it supplied" question is asked once, about one name.
PROFILE_COLUMNS: tuple[str, ...] = ("name", "height_cm", "sex", "dob", "srpa")

# Built by interpolating the hardcoded constant tuple above — never a caller's string.
# Standards section 2 permits f-string SQL only from hardcoded constants, and this site
# says so, which is why the result is cast to `LiteralString` for the type checker.
_COLUMN_LIST = ", ".join(PROFILE_COLUMNS)
_VALUE_LIST = ", ".join("%s" for _ in PROFILE_COLUMNS)
_CONFLICT_SET = ", ".join(
    f"{col} = CASE WHEN %s THEN EXCLUDED.{col} ELSE profile.{col} END" for col in PROFILE_COLUMNS
)
_UPSERT_PROFILE: LiteralString = cast(
    "LiteralString",
    f"INSERT INTO profile (user_id, {_COLUMN_LIST}, updated_at) "
    f"VALUES (%s, {_VALUE_LIST}, now()) "
    f"ON CONFLICT (user_id) DO UPDATE SET {_CONFLICT_SET}, updated_at = now()",
)


def write_profile(
    cur: Cur,
    user_id: UUID,
    *,
    values: dict[str, str | float | date | int | None],
    supplied: frozenset[str],
) -> None:
    """Write the owner's profile, preserving every column ``supplied`` does not name.

    ``values`` carries one entry per :data:`PROFILE_COLUMNS`; ``supplied`` names the
    subset the caller actually received, so an explicit ``null`` (present in both) clears
    while an omission (in neither, or in ``values`` alone) preserves.

    The OWNER is the conflict target (0005 re-keyed the table to `user_id`), which is what
    makes this write tenant-safe: the old target was `(id)` against the single `id = 1`
    row, so any owner's push updated the demographics of whoever held that row — B
    silently overwriting A's height/sex/dob while the row stayed owned by A. Conflicting
    on the owner means a write can only ever reach that owner's own row.

    ``dob`` arrives here as a real ``date``. Both callers convert it themselves and must:
    the ingest path needs the owner's timezone (the app anchors an epoch-ms birth date at
    local midnight, and resolving it in UTC is what stored the owner's birthday one day
    early in production), and the editor's ISO calendar date has no timezone at all.
    """
    cur.execute(
        _UPSERT_PROFILE,
        (
            user_id,
            *(values[col] for col in PROFILE_COLUMNS),
            *(col in supplied for col in PROFILE_COLUMNS),
        ),
    )
