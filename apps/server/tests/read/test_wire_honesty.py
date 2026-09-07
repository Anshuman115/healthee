"""The four places the API could put a wrong or unqualified number on screen.

Each block below is one item of ``docs/BACKEND_GAPS_FROM_UI.md`` section A, and each test
asserts the property the defect violated rather than the shape of the fix — a shape
assertion passes as soon as a key exists, which is how a key that always says the same
thing survives a suite.

A1  a nap's ``stages`` is per-stage TOTALS, as a night's is, and its hypnogram travels
    beside it under its own name. It shipped the raw JSONB array under the totals' key,
    so every nap stage bar in the app rendered blank whatever the strap recorded.
A2  a derived Today card carries its row's date, and a row that is not the reference
    day's withholds its value. The RHR card presented a three-night-old resting heart
    rate as this morning's, with nothing on the wire able to say otherwise.
A3  ``anomalies`` is not an empty list. An empty collection cannot distinguish "nothing
    was anomalous" from "nothing looked", and this endpoint does not look.
A4  every note id a read payload puts on the wire resolves to a manifest ID. Three
    surfaces emitted ALIASES, which resolve to nothing in every consumer of a cited id.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.freshness import NOT_DERIVED_YET
from healthee.insights.manifest import all_notes, note_ids
from healthee.read.activity import activity_snapshot
from healthee.read.fitness import activity_metric
from healthee.read.sleep_page import sleep_page
from healthee.read.today import today_snapshot
from healthee.read.today_series import secondary_cards

pytestmark = pytest.mark.integration

_ZONE = ZoneInfo(SENTINEL_TZ)

# The nap's own staging, in minutes, and the hypnogram that agrees with it.
_NAP_LIGHT_MIN = 22
_NAP_DEEP_MIN = 8
_NAP_TOTAL_MIN = _NAP_LIGHT_MIN + _NAP_DEEP_MIN

# A resting heart rate filed under a day that is NOT the reference day. Far from any
# plausible default, so a leak reads as this number rather than as a rounding artefact.
_STALE_RHR = 71.0


def _reset(cur) -> None:
    for table in ("derived_daily", "sleep_session", "weight_log", "profile", "finding"):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def _daily(cur, day: date, metric: str, value: float, flags: str = "{}") -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, %s, %s, %s::jsonb) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value",
        (SENTINEL_USER_ID, day, metric, value, flags),
    )


def _nap(cur, on: date, *, staged: bool) -> None:
    """One nap on ``on``, with or without a hypnogram; its minute columns are always set."""
    start = datetime.combine(on, time(14, 0), tzinfo=_ZONE)
    end = start + timedelta(minutes=_NAP_TOTAL_MIN)
    stages = (
        [
            [
                int(start.timestamp() * 1000),
                int((start.timestamp() + 60 * _NAP_LIGHT_MIN) * 1000),
                4,
            ],
            [
                int((start.timestamp() + 60 * _NAP_LIGHT_MIN) * 1000),
                int(end.timestamp() * 1000),
                5,
            ],
        ]
        if staged
        else []
    )
    cur.execute(
        "INSERT INTO sleep_session "
        "(user_id,start_ts,end_ts,kind,rem_min,light_min,deep_min,wake_min,stages) "
        "VALUES (%s,%s,%s,'nap',0,%s,%s,0,%s::jsonb) "
        "ON CONFLICT (user_id, start_ts) DO NOTHING",
        (
            SENTINEL_USER_ID,
            start.astimezone(UTC),
            end.astimezone(UTC),
            _NAP_LIGHT_MIN,
            _NAP_DEEP_MIN,
            json.dumps(stages),
        ),
    )


# ── A1. a nap is shaped like a night ─────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_naps_stages_are_the_minute_totals_not_the_raw_hypnogram() -> None:
    """The strap staged this nap; the payload has to be able to say so.

    The old shape put the ``[[startMs, endMs, type]]`` array under ``stages`` — the key a
    NIGHT uses for ``{light, deep, rem, awake}`` minutes — so a client reading totals got
    a list it could make nothing of, and the breakdown was structurally empty for every
    nap that ever existed. This asserts the minutes themselves, so it cannot pass on a
    dict of zeroes.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _nap(cur, today, staged=True)
        naps = sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ)["naps"]

    assert len(naps) == 1
    assert naps[0]["stages"] == {
        "light": _NAP_LIGHT_MIN,
        "deep": _NAP_DEEP_MIN,
        "rem": 0,
        "awake": 0,
    }


@pytest.mark.usefixtures("db")
def test_a_naps_hypnogram_travels_under_its_own_key() -> None:
    """``stage_timeline``, offsets from the nap's start — the night's key, the night's shape."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _nap(cur, today, staged=True)
        timeline = sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ)["naps"][0]["stage_timeline"]

    assert [s["stage"] for s in timeline] == ["light", "deep"]
    assert timeline[0]["start_offset_min"] == 0
    assert timeline[0]["duration_min"] == _NAP_LIGHT_MIN
    assert timeline[1]["end_offset_min"] == _NAP_TOTAL_MIN


@pytest.mark.usefixtures("db")
def test_an_unstaged_nap_keeps_its_totals_and_an_honestly_empty_timeline() -> None:
    """The two halves are independent: no hypnogram is not no staging.

    Naps reach us summarised more often than not, and the minute columns are still real.
    An implementation that derived the totals FROM the hypnogram would zero this nap —
    which is the failure being avoided, not a hypothetical.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _nap(cur, today, staged=False)
        nap = sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ)["naps"][0]

    assert nap["stages"]["light"] == _NAP_LIGHT_MIN
    assert nap["stage_timeline"] == []


# ── A2. a derived card is dated, and a stale one refuses ─────────────────────


@pytest.mark.usefixtures("db")
def test_a_derived_card_carries_the_day_its_row_is_filed_under() -> None:
    """On the common path too — a field that appears only when something is wrong is a
    field the client learns to ignore."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(cur, today, "rhr_daily", 54.0)
        cards = {c["metric"]: c for c in secondary_cards(cur, SENTINEL_USER_ID, SENTINEL_TZ)}

    assert cards["rhr_daily"]["as_of_date"] == today.isoformat()
    assert cards["rhr_daily"]["value"] == 54.0
    assert cards["rhr_daily"]["withheld"] is None


@pytest.mark.usefixtures("db")
def test_an_older_nights_resting_heart_rate_does_not_render_as_the_days() -> None:
    """The defect itself: the newest row is three nights old and the card said nothing.

    ``latest_derived`` answers "the newest row at or before this day", which on a day with
    no row is an older day's — and the card unpacked it and shipped the value bare. The
    assertion is on ``value``, because a date in a field the UI may not render does not
    undo a confident current-looking number (``read/vo2max.py``).
    """
    today = user_today(SENTINEL_TZ)
    three_nights_ago = today - timedelta(days=3)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(cur, three_nights_ago, "rhr_daily", _STALE_RHR)
        cards = {c["metric"]: c for c in secondary_cards(cur, SENTINEL_USER_ID, SENTINEL_TZ)}

    card = cards["rhr_daily"]
    assert card["value"] is None
    assert card["z"] is None
    assert card["anomalous"] is False
    assert card["as_of_date"] == three_nights_ago.isoformat()
    assert card["withheld"]["reason"] == NOT_DERIVED_YET
    assert card["withheld"]["age_days"] == 3
    # The number we DO hold survives inside the block, where nothing can mistake it for
    # the day's own — the shape `derive/freshness.py::withheld_block` fixed.
    assert card["withheld"]["last_value"] == _STALE_RHR


@pytest.mark.usefixtures("db")
def test_the_activity_tab_answers_the_same_way_about_the_same_row() -> None:
    """One row, two surfaces, one answer to "is this current".

    The Activity tab dated its value and served it anyway; the Today card did neither.
    Half the contract on each side is how a stale number moves one tab across instead of
    disappearing.
    """
    today = user_today(SENTINEL_TZ)
    stale_day = today - timedelta(days=3)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(cur, stale_day, "steps_total", 9100.0)
        tab = activity_metric(cur, SENTINEL_USER_ID, SENTINEL_TZ, ["steps_total"])

    assert tab is not None
    assert tab["value"] is None
    assert tab["withheld"]["reason"] == NOT_DERIVED_YET
    assert tab["as_of_date"] == stale_day.isoformat()
    # The trend keeps its own days: a series that ENDS before the reference day is honest
    # as long as nothing claims it ends on it.
    assert [p["date"] for p in tab["trend"]] == [stale_day.isoformat()]


@pytest.mark.usefixtures("db")
def test_a_past_day_with_its_own_row_is_answered_not_withheld() -> None:
    """The gate must not eat the as-of-day feature it sits next to.

    A row filed under 29 July IS 29 July's answer (``docs/AS_OF_DAY.md`` section 1), so
    asking for that day has to produce the number. Without this the previous test could be
    satisfied by a card that never serves anything.
    """
    as_of = user_today(SENTINEL_TZ) - timedelta(days=30)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(cur, as_of, "rhr_daily", _STALE_RHR)
        cards = {
            c["metric"]: c for c in secondary_cards(cur, SENTINEL_USER_ID, SENTINEL_TZ, None, as_of)
        }

    assert cards["rhr_daily"]["value"] == _STALE_RHR
    assert cards["rhr_daily"]["withheld"] is None
    assert cards["rhr_daily"]["as_of_date"] == as_of.isoformat()


# ── A3. an empty list may not mean "not computed" ────────────────────────────


@pytest.mark.usefixtures("db")
def test_anomalies_is_never_an_empty_list_that_reads_as_an_all_clear() -> None:
    """This endpoint does not scan, and the payload has to say which of the two it means.

    ``[]`` is indistinguishable from "nothing was anomalous", so a reader was handed a
    clean bill of health that nothing had computed. The assertion is that it is NOT a
    collection — a test for ``anomalies == []`` was exactly what let the defect stand.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        payload = today_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload["anomalies"] is None
    assert not isinstance(payload["anomalies"], list)
    block = payload["anomalies_withheld"]
    assert block["reason"] == "not_computed_on_this_endpoint"
    assert block["endpoint"] == "/api/notable"
    # The sentence has to deny the all-clear in words, not only by being present.
    assert "all-clear" in block["message"]


# ── A4. a cited id on the wire is an id, never an alias ──────────────────────

# Every key a read payload files a note reference under. Singular and plural both exist
# and both matter; a guard that knew only one of them would pass while the other rotted.
_NOTE_KEYS = (
    "research_notes",
    "research_note",
    "research_note_id",
    "research_note_ids",
    "note_id",
    "note_ids",
)


def _cited(payload: object) -> set[str]:
    """Every note reference anywhere in a payload, by the keys the read layer uses."""
    found: set[str] = set()
    if isinstance(payload, dict):
        for key, value in payload.items():
            if key in _NOTE_KEYS:
                found |= {v for v in ([value] if isinstance(value, str) else value or []) if v}
            found |= _cited(value)
    elif isinstance(payload, list):
        for item in payload:
            found |= _cited(item)
    return found


@pytest.mark.usefixtures("db")
def test_every_note_id_on_the_wire_resolves_to_a_manifest_id() -> None:
    """Not to an alias. An alias resolves to NOTHING in the behaviour that matters.

    The app's ⓘ sheet renders the note for a cited id, and every consumer of one looks it
    up by id — ``manifest.by_id`` / ``note_ids`` / ``grade_of``, none of which read
    ``aliases``. So ``cardio_load_trimp`` (a live alias of ``training_stress_score``) and
    ``vo2max_fitness_mortality`` (of ``vo2max``) opened an empty sheet on three surfaces
    while looking perfectly healthy in a grep. ``tests/test_source_citations.py`` holds
    the same rule for ``[[id]]`` citations in source; this holds it for the wire.
    """
    known = note_ids()
    assert known, "manifest is empty — the guard would pass vacuously"
    aliases = {a for n in all_notes() for a in n.aliases}
    assert "cardio_load_trimp" in aliases, "fixture drifted: expected this alias to exist"

    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(cur, today, "rhr_daily", 54.0)
        _daily(cur, today, "cardio_load", 120.0)
        _daily(cur, today, "mvpa_min", 30.0, json.dumps({"moderate": 25, "vigorous": 5}))
        _daily(cur, today, "hrv_sleep_avg", 44.0)
        cited = _cited(today_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ))
        cited |= _cited(activity_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ))
        cited |= _cited(sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ))

    assert cited, "no note ids reached the wire — the guard would pass vacuously"
    unresolved = sorted(n for n in cited if n not in known)
    assert not unresolved, f"note references on the wire that are not manifest ids: {unresolved}"
