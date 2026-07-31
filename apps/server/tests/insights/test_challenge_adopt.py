"""``adopt_challenge`` against real rows — and the ambiguity it refuses to resolve.

WP-C5, CHALLENGES.md §6. The tool's whole job is deciding WHICH suggestion was meant;
every lifecycle rule (suggested-only, the cap, cadence expressibility, the baseline
frozen at adopt) belongs to ``lifecycle.adopt`` and is asserted here only where the tool
must not have re-implemented it.

The property that carries the most weight: **ambiguity refuses**. Legacy adopted "by
title match" and took the first hit — a challenge somebody did not choose, reported to
them as one they did, is exactly the small confident lie this product exists not to tell.
"""

from __future__ import annotations

import pytest
from tests.challenges import _gen, _seed
from tests.insights import _challenge_bed as bed

from healthee.core.db import tenant_transaction
from healthee.insights import challenge_tools

pytestmark = pytest.mark.integration


# ── adopt_challenge ───────────────────────────────────────────────────────────


def test_adopting_by_id_starts_it_and_reports_the_stored_row(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    challenge_id = bed.suggest(title="Walk a little more", target_value=6250.0)

    result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, challenge_id=challenge_id)

    assert result["ok"] is True
    # The STORED target, not one the model might have had in mind (INTELLIGENCE §4).
    assert result["challenge"]["target_value"] == 6250.0
    assert result["challenge"]["status"] == "active"
    assert bed.stored(challenge_id)["status"] == "active"


def test_adopting_freezes_the_baseline_the_lifecycle_computes(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    """The tool must not invent the anchor either — ``lifecycle.adopt`` owns that rule."""
    challenge_id = bed.suggest()

    result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, challenge_id=challenge_id)

    assert result["challenge"]["baseline_value"] == _gen.BASELINE_STEPS


def test_adopting_by_title_resolves_the_one_suggestion_it_names(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    walking = bed.suggest(title="Walk a little more")
    bed.suggest(title="Steadier bedtimes", metric="sri", target_value=60.0)

    result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, reference="walk a little more")

    assert result["ok"] is True
    assert int(result["challenge"]["id"]) == walking


def test_an_exact_title_beats_a_mere_containment(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    """Tiering is not preference — an equality is strictly more evidence than a substring."""
    exact = bed.suggest(title="Walk more")
    bed.suggest(title="Walk more before dinner", metric="mvpa_min", target_value=30.0)

    result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, reference="Walk more")

    assert result["ok"] is True
    assert int(result["challenge"]["id"]) == exact


def test_an_ambiguous_reference_refuses_and_starts_nothing(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    first = bed.suggest(title="Walk more each morning")
    second = bed.suggest(title="Walk more after dinner", metric="mvpa_min", target_value=30.0)

    result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, reference="walk more")

    assert result["ok"] is False
    assert result["reason"] == "ambiguous"
    assert {row["challenge_id"] for row in result["suggested"]} == {first, second}
    assert [bed.stored(cid)["status"] for cid in (first, second)] == ["suggested", "suggested"]


def test_a_reference_that_matches_nothing_refuses_and_says_what_is_on_offer(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    challenge_id = bed.suggest(title="Walk a little more")

    result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, reference="cold plunges")

    assert (result["ok"], result["reason"]) == (False, "no_match")
    assert [row["challenge_id"] for row in result["suggested"]] == [challenge_id]
    assert bed.stored(challenge_id)["status"] == "suggested"


def test_an_id_that_does_not_exist_refuses_through_the_lifecycle(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    """Not re-implemented here: ``lifecycle.adopt`` owns "no such challenge"."""
    result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, challenge_id=987654)

    assert (result["ok"], result["reason"]) == (False, "not_found")


def test_another_owners_challenge_is_not_found_rather_than_forbidden(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    """A 404 that becomes a 403 for the ids that exist confirms another tenant's ids."""
    _seed.ensure_owner_b()
    try:
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            theirs = _seed.seed_challenge(cur, _seed.OTHER_OWNER, title="B's own")

        result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, challenge_id=theirs)

        assert (result["ok"], result["reason"]) == (False, "not_found")
        with tenant_transaction(_seed.OTHER_OWNER) as cur:
            assert _seed.stored(cur, _seed.OTHER_OWNER, theirs)["status"] == "suggested"
    finally:
        _seed.remove_owner_b()


def test_adopting_with_nothing_suggested_refuses(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    result = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, reference="anything")

    assert (result["ok"], result["reason"]) == (False, "nothing_suggested")


def test_adopting_an_already_active_challenge_refuses(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    challenge_id = bed.suggest()
    challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, challenge_id=challenge_id)

    again = challenge_tools.adopt_challenge(bed.OWNER, bed.TZ, challenge_id=challenge_id)

    assert (again["ok"], again["reason"]) == (False, "not_suggested")


# ── dispatch ──────────────────────────────────────────────────────────────────


def test_the_coach_dispatches_both_tools_by_name(
    challenge_owner_with_history: None,  # noqa: ARG001
) -> None:
    from healthee.insights import coach_tools

    challenge_id = bed.suggest()

    result = coach_tools.execute_tool(
        "adopt_challenge", {"challenge_id": challenge_id}, bed.OWNER, bed.TZ
    )

    assert result["ok"] is True
    offered = {t["function"]["name"] for t in coach_tools.COACH_TOOLS}
    assert offered.issuperset(challenge_tools.TOOL_NAMES)
    assert coach_tools.ACTION_TOOLS.issuperset(challenge_tools.TOOL_NAMES)
