"""C3 — the abandon cooldown is bounded by the cooldown, not by a row count.

``_recently_abandoned`` decides whether a metric the owner walked away from may be
re-offered, and the rule is a 60-day one (``ABANDON_COOLDOWN_DAYS``). It used to read
``ledger.recent(limit=50)``, justified as *"these two rules only care about the LATEST
row per metric, and there are nine metrics"* — which is not what makes 50 sufficient.
What made it sufficient was an unstated invariant, *fewer than ~50 outcomes are frozen
in any 60 days*, and the legal worst case exceeds it: ``lifecycle.MAX_ACTIVE = 3``
concurrent challenges at ``gen_prompt.MIN_WINDOW_DAYS = 3`` is up to 60 outcomes in 60
days. Past row 50 an abandonment read as *never abandoned* and the metric was re-offered
inside its own cooldown.

The window has two edges and both are asserted: deep history no longer hides an
abandonment, and an abandonment older than the cooldown still does not block. Seeded
against the real ledger — a stubbed row list would be testing the stub, and the defect
lived in the SQL bound.

Widening it surfaced a SECOND defect in the same function, closed with it and pinned by
the last test here: the loop did not take the latest row per metric the way its own
docstring said, so a completion after an abandonment did not clear the cooldown.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from tests.challenges import _seed

from healthee.challenges import levers
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ
from healthee.db import migrate

pytestmark = pytest.mark.integration

IST = SENTINEL_TZ
TODAY = date(2026, 7, 15)

# Comfortably past the old 50-row tail, and inside the legal throughput: three live
# challenges at a three-day window is up to 60 outcomes in 60 days.
_NEWER_ROWS = 60


@pytest.fixture
def owner(db: None) -> Iterator[None]:  # noqa: ARG001 — gates on DB reachability
    migrate.apply_migrations()
    _seed.reset()
    yield
    _seed.reset()


def _freeze(cur, metric: str, status: str, ended: datetime) -> None:
    """One frozen outcome for ``metric``, ended at ``ended``.

    The challenge's own terminal status and the OUTCOME's are separate vocabularies
    (`challenge_status_chk` vs the ledger's), so only the second one varies here — the
    ledger read is what these tests are about.
    """
    challenge_id = _seed.seed_challenge(
        cur,
        _seed.OWNER,
        metric=metric,
        status="abandoned" if status == "abandoned" else "completed",
    )
    _seed.seed_outcome(cur, _seed.OWNER, challenge_id, metric=metric, status=status, ended_at=ended)


def _abandoned(today: date = TODAY) -> dict[str, date]:
    with tenant_transaction(_seed.OWNER) as cur:
        return levers._recently_abandoned(cur, _seed.OWNER, IST, today)


def test_deep_history_no_longer_hides_an_abandonment_inside_its_cooldown(
    owner: None,  # noqa: ARG001
) -> None:
    """THE finding: the abandonment sits past row 50 and must still block a re-offer.

    Sixty NEWER outcomes on other metrics push it out of any fifty-row tail. Nothing
    about the rule changed — it is still "the latest row for this metric is an
    abandonment inside 60 days" — only whether the read can see the row.
    """
    walked_away = datetime(2026, 6, 20, 6, 0, tzinfo=UTC)  # 25 days back: inside cooldown
    with tenant_transaction(_seed.OWNER) as cur:
        _freeze(cur, "steps_total", "abandoned", walked_away)
        for i in range(_NEWER_ROWS):
            _freeze(cur, "mvpa_min", "met", walked_away + timedelta(days=1, minutes=i))

    assert _abandoned().get("steps_total") == date(2026, 6, 20), (
        "an abandonment past the old 50-row tail read as never abandoned"
    )


def test_an_abandonment_older_than_the_cooldown_does_not_block(
    owner: None,  # noqa: ARG001
) -> None:
    """The other edge. Sixty-one days back is out of cooldown and must be re-offerable.

    A window that reached further than the rule would be its own defect: the cooldown
    exists so the re-offer is not the same conversation, and a rule that never expires
    would take a metric off the menu for good.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _freeze(
            cur,
            "steps_total",
            "abandoned",
            datetime(2026, 7, 15, 6, 0, tzinfo=UTC) - timedelta(days=61),
        )

    assert _abandoned() == {}


def test_the_boundary_day_is_still_inside_the_cooldown(
    owner: None,  # noqa: ARG001
) -> None:
    """Exactly 60 local days back: ``(today - ended_on).days <= 60`` keeps it.

    The window's opening instant is the START of that local day, so the earliest
    qualifying outcome is reachable however late in the day it was frozen.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _freeze(
            cur,
            "steps_total",
            "abandoned",
            datetime(2026, 5, 16, 23, 30, tzinfo=UTC),  # 2026-05-17 in IST, 59 days back
        )

    assert _abandoned().get("steps_total") == date(2026, 5, 17)


def test_a_later_non_abandonment_still_clears_the_metric(
    owner: None,  # noqa: ARG001
) -> None:
    """A second defect in the same function, found by widening the read.

    "The metric's MOST RECENT outcome is an abandonment" is what the docstring always
    claimed; the loop marked a metric decided only when it RECORDED an abandonment, so a
    later completion did not stop the walk and the older abandonment was found underneath
    it. The 50-row tail hid how reachable that was. They walked away, then came back and
    finished one — the cooldown is about the ones they did not come back to.
    """
    with tenant_transaction(_seed.OWNER) as cur:
        _freeze(cur, "steps_total", "abandoned", datetime(2026, 6, 20, 6, 0, tzinfo=UTC))
        _freeze(cur, "steps_total", "met", datetime(2026, 7, 1, 6, 0, tzinfo=UTC))

    assert _abandoned() == {}
