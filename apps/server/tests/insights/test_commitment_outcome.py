"""What a kept commitment's metric did — and the four ways this refuses to overclaim.

C2's third evidence source. The first two were already unified in practice: the
`finding` table's correlations and the frozen challenge ledger, both rendered into
the coach's context and both cited `[personal_finding:…]`. This adds the one C1
created and nothing read.

The assertions that matter are the negative ones, because a commitment before/after
is the WEAKEST of the three claims — no target, no adoption gate, self-reported
adherence — and the temptation is to compute it by a softer rule than the ledger
that has all three. It uses the ledger's estimator and the ledger's line.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from uuid import UUID, uuid4

import pytest

from healthee.challenges.series import MIN_COMPARISON_DAYS
from healthee.core.db import tenant_transaction, transaction
from healthee.db import migrate
from healthee.insights import coach_context, commitment_outcome, commitments

pytestmark = [pytest.mark.integration, pytest.mark.usefixtures("owner_sweep")]

_TZ = "UTC"
_METRIC = "steps_total"


def _owner() -> UUID:
    uid = uuid4()
    with transaction() as cur:
        cur.execute("INSERT INTO app_user (id, email) VALUES (%s, NULL)", (str(uid),))
    return uid


def _seed(uid: UUID, day: date, value: float) -> None:
    """RLS-scoped, like every other write in the app.

    A plain ``transaction()`` runs as the app role with no ``healthee.user_id``
    set, so the row is refused by the tenant policy rather than written to the
    wrong owner — which is the policy working, and is why this seeds the way the
    product does.
    """
    with tenant_transaction(uid) as cur:
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value) "
            "VALUES (%s, %s, %s, %s) "
            "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
            (str(uid), day, _METRIC, value),
        )


def test_a_real_before_and_after_is_reported_with_both_day_counts(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    uid = _owner()
    since = date.today() - timedelta(days=10)
    for i in range(1, 9):  # eight days before the commitment
        _seed(uid, since - timedelta(days=i), 5000)
    for i in range(0, 9):  # and eight after
        _seed(uid, since + timedelta(days=i), 9000)

    out = commitment_outcome.outcome_for(uid, _TZ, 1, "walk after dinner", _METRIC, since)

    assert out.confidence == commitment_outcome.OK
    assert out.before == 5000
    assert out.after == 9000
    assert out.delta == 4000
    # The day counts travel with the numbers: a mean over four days and one over
    # thirty look identical, and only one of them is worth a sentence.
    assert out.before_days >= MIN_COMPARISON_DAYS
    assert out.after_days >= MIN_COMPARISON_DAYS


def test_a_thin_window_carries_NO_NUMBERS_at_all(db: None) -> None:  # noqa: ARG001, N802
    """A value beside an `insufficient_data` label is the number people read.

    The challenge ledger blanks them for exactly this reason, and a weaker claim
    must not be more forthcoming than a stronger one.
    """
    migrate.apply_migrations()
    uid = _owner()
    since = date.today() - timedelta(days=3)
    _seed(uid, since - timedelta(days=1), 5000)
    _seed(uid, since + timedelta(days=1), 9000)

    out = commitment_outcome.outcome_for(uid, _TZ, 1, "walk after dinner", _METRIC, since)

    assert out.confidence == commitment_outcome.INSUFFICIENT
    assert out.before is None
    assert out.after is None
    assert out.delta is None


def test_a_confound_in_the_window_is_reported_as_structure(db: None) -> None:  # noqa: ARG001
    """ "Something else was also going on" is the sentence that stops a delta reading
    as a result — so it is data, not prose the coach might omit."""
    migrate.apply_migrations()
    uid = _owner()
    since = date.today() - timedelta(days=10)
    for i in range(1, 9):
        _seed(uid, since - timedelta(days=i), 5000)
        _seed(uid, since + timedelta(days=i - 1), 9000)
    with tenant_transaction(uid) as cur:
        cur.execute(
            "INSERT INTO illness_flag (user_id, date, severity, research_note_ids) "
            "VALUES (%s, %s, 'moderate', '{}')",
            (str(uid), since + timedelta(days=2)),
        )

    out = commitment_outcome.outcome_for(uid, _TZ, 1, "walk after dinner", _METRIC, since)
    assert out.confounds["illness_days"] >= 1


def test_only_KEPT_commitments_WITH_a_metric_become_evidence(db: None) -> None:  # noqa: ARG001, N802
    """A missed commitment is not a behaviour change, and "get to bed earlier"
    names nothing to compare. Neither is evidence, and neither is invented into one."""
    migrate.apply_migrations()
    uid = _owner()

    commitments.record(uid, _TZ, "kept with a metric", _METRIC, 7)
    commitments.record(uid, _TZ, "kept without one", None, 7)
    commitments.record(uid, _TZ, "missed one", _METRIC, 7)

    by_text = {c.stated: c.id for c in commitments.open_commitments(uid)}
    commitments.resolve(uid, by_text["kept with a metric"], "kept")
    commitments.resolve(uid, by_text["kept without one"], "kept")
    commitments.resolve(uid, by_text["missed one"], "missed")

    evidence = commitments.kept_with_metric(uid)
    assert [c.stated for c in evidence] == ["kept with a metric"]


def test_a_FRESH_commitment_has_no_outcome_yet(db: None) -> None:  # noqa: ARG001, N802
    """The measured-days gate is not enough on its own, and this is why.

    The estimator averages a trailing `BASELINE_DAYS`. Five days after a commitment
    that window still reaches two days back over it, so both sides are dense, both
    day counts clear `MIN_COMPARISON_DAYS` — and the "after" is partly the baseline.
    The delta would be real arithmetic on the wrong window.
    """
    migrate.apply_migrations()
    uid = _owner()
    since = date.today() - timedelta(days=5)
    for i in range(1, 11):
        _seed(uid, since - timedelta(days=i), 5000)
    for i in range(0, 5):
        _seed(uid, since + timedelta(days=i), 9000)

    out = commitment_outcome.outcome_for(uid, _TZ, 1, "walk after dinner", _METRIC, since)

    # Dense enough to have passed the other gate — which is the point of the test.
    assert out.before_days >= MIN_COMPARISON_DAYS
    assert out.after_days >= MIN_COMPARISON_DAYS
    assert out.confidence == commitment_outcome.INSUFFICIENT
    assert out.delta is None


def _backdate(uid: UUID, commitment_id: int, day: date) -> None:
    """Backdate a commitment, because the block anchors the window on `created_at`.

    A commitment recorded a moment ago has zero days of "after" whatever the metric
    rows say, so a rendering test that did not do this would only ever exercise the
    insufficient branch — which is exactly how this helper came to exist.
    """
    with tenant_transaction(uid) as cur:
        cur.execute(
            "UPDATE coach_commitment SET created_at = %s WHERE id = %s",
            (day, commitment_id),
        )


def _kept_block(uid: UUID) -> str:
    """The rendered block, which is where the honesty claim actually reaches the model."""
    return coach_context._kept_outcomes_block(uid, _TZ)  # noqa: SLF001


def test_the_rendered_block_states_the_delta_and_the_day_counts(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    uid = _owner()
    since = date.today() - timedelta(days=10)
    for i in range(1, 9):
        _seed(uid, since - timedelta(days=i), 5000)
    for i in range(9):
        _seed(uid, since + timedelta(days=i), 9000)
    commitments.record(uid, _TZ, "walk after dinner", _METRIC, 7)
    (c,) = commitments.open_commitments(uid)
    _backdate(uid, c.id, since)
    commitments.resolve(uid, c.id, "kept")

    block = _kept_block(uid)

    assert "[personal_finding:commitment]" in block
    assert "5000.0 → 9000.0" in block
    # Observational, and it says so in the block rather than hoping the model recalls it.
    assert "nothing here shows the change caused them" in block


def test_an_insufficient_outcome_RENDERS_no_number(db: None) -> None:  # noqa: ARG001, N802
    """The estimator withholding the numbers is only half of it.

    The block is what the model reads, so this asserts on the text: a thin outcome
    must not print a value, a delta or an arrow beside the words "not enough".
    """
    migrate.apply_migrations()
    uid = _owner()
    since = date.today() - timedelta(days=2)
    _seed(uid, since - timedelta(days=1), 5000)
    _seed(uid, since + timedelta(days=1), 9000)
    commitments.record(uid, _TZ, "walk after dinner", _METRIC, 7)
    (c,) = commitments.open_commitments(uid)
    commitments.resolve(uid, c.id, "kept")

    block = _kept_block(uid)

    assert "not enough measured days" in block
    assert "→" not in block
    assert "5000" not in block
    assert "9000" not in block


def test_the_window_is_anchored_on_THEIR_day_not_UTC(db: None) -> None:  # noqa: ARG001, N802
    """A `TIMESTAMPTZ` read as a UTC date moves the anchor by one for half the world.

    02:00 in Kolkata is 20:30 the previous day in UTC. The anchor is what splits
    before from after, so the naive reading files the first day of the change as
    part of its own baseline — a whole day, for every owner east of Greenwich who
    talks to the coach at night.
    """
    made = datetime(2026, 9, 8, 20, 30, tzinfo=UTC)  # 2026-09-09 02:00 in Kolkata

    assert coach_context._made_on(made, "Asia/Kolkata") == date(2026, 9, 9)  # noqa: SLF001
    assert coach_context._made_on(made, "UTC") == date(2026, 9, 8)  # noqa: SLF001
