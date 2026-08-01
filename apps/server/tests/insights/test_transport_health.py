"""The transport record: a blip is not an outage, and "unknown" is never "ok".

The incident these pin: the account hit its ceiling, every LLM call 402'd for hours, and
`/healthz` was green throughout. The record below is what makes that state *sayable*,
so the properties that matter are the ones an alert is built on — the streak, the reset,
the four states, and the fact that nothing the provider wrote reaches our storage.

No network anywhere: exceptions are constructed by hand, which is also the only way to
exercise the 402 path deliberately.
"""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from healthee.insights import transport_health as th


class _StatusError(Exception):
    """Stands in for `openai.APIStatusError` — the SDK error shape, without the import."""

    def __init__(self, status_code: int, message: str = "provider said something") -> None:
        super().__init__(message)
        self.status_code = status_code


class APITimeoutError(Exception):
    """Named to match the SDK class the kind table keys on."""


@pytest.fixture(autouse=True)
def _fresh() -> None:
    th.reset()


# ── the four states ───────────────────────────────────────────────────────────


def test_a_process_that_has_made_no_call_is_unknown_not_ok() -> None:
    """The conversion this whole feature exists to prevent: "we don't know" → "we're fine"."""
    assert th.snapshot().status == th.UNKNOWN


def test_one_success_makes_it_ok() -> None:
    th.record_success()
    assert th.snapshot().status == th.OK


def test_one_failure_is_degraded_and_does_not_page() -> None:
    """A single 402 is noise. Alerting on it trains its reader to ignore the channel."""
    th.record_failure(_StatusError(402))
    assert th.snapshot().status == th.DEGRADED


def test_the_outage_threshold_is_where_degraded_becomes_down() -> None:
    for _ in range(th.OUTAGE_THRESHOLD - 1):
        th.record_failure(_StatusError(402))
    assert th.snapshot().status == th.DEGRADED, "paged before the threshold"
    th.record_failure(_StatusError(402))
    assert th.snapshot().status == th.DOWN


def test_a_success_anywhere_clears_the_streak() -> None:
    """The record is a statement about the present, not a lifetime error count."""
    for _ in range(th.OUTAGE_THRESHOLD):
        th.record_failure(_StatusError(500))
    assert th.snapshot().status == th.DOWN
    th.record_success()
    snapshot = th.snapshot()
    assert snapshot.status == th.OK
    assert snapshot.consecutive_failures == 0


def test_the_streak_counts_any_kind_while_the_diagnosis_is_the_latest_one() -> None:
    """ "Has anything got through?" and "what is wrong?" are different questions."""
    th.record_failure(APITimeoutError())
    th.record_failure(_StatusError(402))
    th.record_failure(_StatusError(402))
    snapshot = th.snapshot()
    assert snapshot.status == th.DOWN
    assert snapshot.consecutive_failures == 3
    assert snapshot.last_error_kind == th.CREDIT


# ── classification ────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("status_code", "kind"),
    [(402, th.CREDIT), (401, th.AUTH), (403, th.AUTH), (429, th.RATE_LIMIT), (500, th.HTTP)],
)
def test_http_statuses_classify_to_the_kind_an_operator_acts_on(
    status_code: int, kind: str
) -> None:
    assert th.classify(_StatusError(status_code)) == (kind, status_code)


def test_a_timeout_classifies_without_importing_the_sdk() -> None:
    """Matched by class NAME so `client._client`'s deliberate lazy import stays lazy."""
    assert th.classify(APITimeoutError()) == (th.TIMEOUT, None)


def test_an_unrecognised_exception_is_named_not_silently_treated_as_fine() -> None:
    kind, status = th.classify(RuntimeError("something new"))
    assert (kind, status) == (th.UNCLASSIFIED, None)


def test_an_unrecognised_exception_still_counts_toward_the_outage() -> None:
    """The classification changes the WORDS in an alert; it must never gate the alert."""
    for _ in range(th.OUTAGE_THRESHOLD):
        th.record_failure(RuntimeError("something new"))
    assert th.snapshot().status == th.DOWN


@pytest.mark.parametrize(
    ("status_code", "permanent"),
    [(402, True), (401, True), (403, True), (429, False), (500, False)],
)
def test_will_not_self_heal_splits_patience_from_a_human_with_a_credit_card(
    status_code: int, permanent: bool
) -> None:
    th.record_failure(_StatusError(status_code))
    assert th.snapshot().will_not_self_heal is permanent


# ── what is NOT recorded ──────────────────────────────────────────────────────


def test_the_providers_message_never_reaches_the_record() -> None:
    """A 400 body for a bad model id contains that id verbatim, and the id is a secret.

    The record carries kind + status code, and the dataclass has nowhere to put free
    text — asserted over every field so adding one later fails here rather than leaking.
    """
    secret = "vendor-x/never-log-me-9000"
    th.record_failure(_StatusError(400, f"{secret} is not a valid model ID"))
    stored = " ".join(str(value) for value in vars(th.snapshot()).values())
    assert secret not in stored
    assert "not a valid model" not in stored


def test_crossing_the_threshold_logs_the_pattern_no_single_stack_trace_can_state(
    caplog: pytest.LogCaptureFixture,
) -> None:
    with caplog.at_level("WARNING"):
        for _ in range(th.OUTAGE_THRESHOLD):
            th.record_failure(_StatusError(402, "vendor-x/never-log-me-9000 out of credits"))
    warnings = "\n".join(r.getMessage() for r in caplog.records)
    assert "DOWN" in warnings and "credit" in warnings
    assert "never-log-me" not in warnings


def test_timestamps_are_recorded_for_both_outcomes() -> None:
    when = datetime(2026, 8, 1, 12, 0, tzinfo=UTC)
    th.record_success(now=when)
    th.record_failure(_StatusError(402), now=when)
    snapshot = th.snapshot()
    assert snapshot.last_ok_at == when
    assert snapshot.last_failure_at == when


def test_a_snapshot_is_frozen_so_a_reader_cannot_see_a_half_written_record() -> None:
    snapshot = th.snapshot()
    with pytest.raises(Exception):  # noqa: B017 — frozen dataclass raises FrozenInstanceError
        snapshot.consecutive_failures = 99  # type: ignore[misc]
