"""Today snapshot — GET /api/today (Bearer-auth).

Thin (standards §2): authorize → one cursor → the read service → the payload. The
response is a large nested aggregate whose shape is pinned by the contract
snapshot test rather than a pydantic model (a 25-key nested model would be more
brittle than the golden snapshot it duplicates).

**Free endpoint, two premium fields.** Every metric, chart, baseline and finding here
is free tier (``PRICING.md`` §1a) and stays served — but the ``action`` line and the
``recommendations`` list are LLM-authored, so for a non-premium owner they are OMITTED
from the payload entirely and a ``locked`` marker takes their place (``api.gate``).
Omitted, not nulled: ``MULTI_USER.md`` §12.7's closure for "sniff /api/today to read
the AI fields the app hides" is that the data is not in the response at all.

**``day=YYYY-MM-DD`` answers for that day** (``docs/AS_OF_DAY.md``). Absent, it answers
for the owner's today exactly as it always has.
"""

from __future__ import annotations

from fastapi import APIRouter

from healthee.api.gate import DAILY_ACTION, TODAY_AI_FIELDS, gate_free_payload
from healthee.api.validation import require_reference_day
from healthee.core.db import tenant_transaction
from healthee.core.request_auth import CurrentUser
from healthee.insights import coaching
from healthee.read.today import today_snapshot

router = APIRouter(tags=["today"])


@router.get("/api/today")
def get_today(user: CurrentUser, day: str | None = None) -> dict:
    """Aggregated snapshot for one day + the grounded daily action line.

    The ``action`` is the WP5 coaching one-liner: read-only from the per-day cache
    (``None`` until the scheduler warms it), so this read path never calls the LLM.

    **It is null on any day but today, and that is the scope line.** The cache is keyed
    on the owner's current day, so there is no stored line for an older one — and
    generating one now would be authoring a new claim under an old date rather than
    replaying a record (``docs/AS_OF_DAY.md`` section 6). The app already renders a null
    action by showing nothing, which is the honest default.
    """
    as_of = require_reference_day(day, user.timezone)
    with tenant_transaction(user.id) as cur:
        payload = today_snapshot(cur, user.id, user.timezone, as_of)
    payload["action"] = (
        coaching.cached_line(user.id, user.timezone, coaching.DAILY_ACTION_KEY)
        if payload["as_of"]["is_today"]
        else None
    )
    return gate_free_payload(user, payload, TODAY_AI_FIELDS, DAILY_ACTION)
