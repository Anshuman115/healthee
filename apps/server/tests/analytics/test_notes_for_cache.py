"""`notes_for` is memoised, and the cache cannot leak into a caller (`PERF_AUDIT.md` B3).

`correlate` calls this once per finding — 774 times a night for one owner — and the
answer depends on nothing but the manifest, which `_records` already caches for the whole
life of the process. So the memo adds speed and no staleness.

What a memo CAN add is a shared mutable object. `Finding.research_note_ids` is a plain
list that later code is free to sort, extend or clear; if that list were the cached one,
one finding's edit would silently become every subsequent finding's note list. The cache
therefore holds a tuple and every call copies out of it, and that is asserted here rather
than trusted — a leak of this kind produces plausible note ids on the wrong claim, which
is the failure the whole citation layer exists to prevent.

The key is asserted too: two different metric lists must not collide, and interventions
must be part of what distinguishes them.
"""

from __future__ import annotations

from healthee.analytics.notes import notes_for

# `caffeine` adds `caffeine_sleep` to `rhr_daily`'s notes and nothing else does, so an
# intervention dropped from the cache key changes the answer here. Chosen by asking the
# manifest rather than by guessing: the assertion below fails loudly if this pair ever
# stops distinguishing the two, so the fixture cannot rot into a tautology.
_INTERVENTION = "caffeine"
_METRIC = "rhr_daily"


def test_the_same_question_twice_gives_equal_but_separate_lists() -> None:
    """Equal by value, not the same object — and a `list`, which callers rely on."""
    first = notes_for(["rhr_daily", "hrv_sleep_avg"])
    second = notes_for(["rhr_daily", "hrv_sleep_avg"])

    assert isinstance(first, list), "callers treat this as a list; a tuple is a break"
    assert first == second
    assert first is not second, (
        "the same object came back twice — the cache is handing out its own list, and "
        "one caller's edit becomes every later caller's note ids"
    )


def test_mutating_the_result_does_not_change_the_next_answer() -> None:
    """The leak, asked directly: clear what you were given, ask again, get it all back."""
    first = notes_for(["rhr_daily"])
    expected = list(first)
    first.clear()
    first.append("not_a_real_note")

    assert notes_for(["rhr_daily"]) == expected, (
        "a mutation of one caller's result reached the cache — the next finding would "
        "cite whatever the last caller left behind"
    )


def test_interventions_are_part_of_what_the_cache_keys_on() -> None:
    """The same metrics with and without an intervention are different questions."""
    without = notes_for([_METRIC])
    with_intervention = notes_for([_METRIC], [_INTERVENTION])

    assert set(without) <= set(with_intervention), (
        "adding an intervention can only ever add notes; it must not drop any"
    )
    assert with_intervention != without, (
        f"{_INTERVENTION!r} added no note, so this fixture cannot tell a cache that keys "
        "on interventions from one that ignores them — pick one that matches"
    )


def test_different_metrics_are_different_questions() -> None:
    """A key that collapsed to a constant would return one owner's notes for everything."""
    a = notes_for(["rhr_daily"])
    b = notes_for(["sleep_health_score_4dim"])

    assert a != b, "two different metric lists returned the identical note list"
