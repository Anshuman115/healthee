"""Tests for the contract shape checker itself.

`shape.py` is the thing that decides whether a server↔mobile contract has drifted,
so its own failure modes matter as much as the contracts it guards. The load-bearing
case is a field DROPPED from inside a list of objects: under the per-element subset
rule alone, the live elements stayed a subset and the contract passed while the app
lost a field. These tests pin that it now fails — and that the union lists the subset
rule exists for still pass.

No DB: `assert_conforms` is pure, and an integration-marked test would auto-skip.
"""

from __future__ import annotations

import pytest
from tests.contracts.shape import assert_conforms


def _conforms(live: object, snap: object) -> bool:
    try:
        assert_conforms(live, snap, "root")
    except AssertionError:
        return False
    return True


# ── The bug: a field removed from inside a list of objects ──────────────────


def test_field_dropped_from_every_list_element_is_caught() -> None:
    """THE regression. Live elements are still a subset of the snapshot union, so the
    subset rule passes them; only the union-coverage rule sees `hr` is gone."""
    snap = [{"term": "fitness", "hr": 0.85}, {"term": "regularity", "hr": 1.17}]
    live = [{"term": "fitness"}, {"term": "regularity"}]
    assert not _conforms(live, snap)


def test_field_dropped_from_a_single_element_list_is_caught() -> None:
    snap = [{"term": "fitness", "delta_years": -1.8}]
    live = [{"term": "fitness"}]
    assert not _conforms(live, snap)


def test_error_names_the_dropped_field() -> None:
    snap = [{"term": "fitness", "hr": 0.85, "unit": "ml/kg/min"}]
    live = [{"term": "fitness", "unit": "ml/kg/min"}]
    with pytest.raises(AssertionError, match=r"\['hr'\].*NO live element"):
        assert_conforms(live, snap, "root")


def test_unchanged_object_list_still_passes() -> None:
    snap = [{"term": "fitness", "hr": 0.85}]
    live = [{"term": "regularity", "hr": 1.17}]
    assert _conforms(live, snap)


# ── The reason the subset rule exists: heterogeneous / union lists ──────────


def test_heterogeneous_union_list_still_passes() -> None:
    """No element carries every key, but the live union covers the snapshot union —
    exactly the shape the subset rule was written for. Must not false-positive."""
    snap = [
        {"kind": "gps", "distance_m": 5000},
        {"kind": "manual", "note": "felt easy"},
    ]
    live = [
        {"kind": "gps", "distance_m": 8000},
        {"kind": "manual", "note": "hard"},
    ]
    assert _conforms(live, snap)


def test_union_list_passes_when_one_element_supplies_the_key() -> None:
    """The live mix differs from the snapshot's, but every snapshot key is still
    present on SOME live element, so nothing was dropped."""
    snap = [{"kind": "gps", "distance_m": 5000}, {"kind": "manual", "note": "x"}]
    live = [{"kind": "gps", "distance_m": 1, "note": "y"}]
    assert _conforms(live, snap)


def test_union_list_missing_a_key_entirely_is_caught() -> None:
    """A union list where `note` vanished from every element is still a removal."""
    snap = [{"kind": "gps", "distance_m": 5000}, {"kind": "manual", "note": "x"}]
    live = [{"kind": "gps", "distance_m": 1}, {"kind": "manual"}]
    assert not _conforms(live, snap)


def test_extra_key_not_in_the_snapshot_union_still_fails() -> None:
    snap = [{"term": "fitness", "hr": 0.85}]
    live = [{"term": "fitness", "hr": 0.85, "surprise": 1}]
    assert not _conforms(live, snap)


# ── Empty lists ────────────────────────────────────────────────────────────


def test_empty_live_list_is_not_a_false_alarm() -> None:
    """No elements means no union to compare — an empty list is legitimate on a real
    dataset (no workouts logged), not a dropped field."""
    snap = [{"term": "fitness", "hr": 0.85}]
    assert _conforms([], snap)


def test_empty_snapshot_list_accepts_anything() -> None:
    assert _conforms([{"anything": 1}], [])


def test_both_empty_lists_pass() -> None:
    assert _conforms([], [])


# ── Nested lists ───────────────────────────────────────────────────────────


def test_field_dropped_from_a_nested_list_is_caught() -> None:
    snap = {"biological_age": {"contributions": [{"term": "fitness", "hr": 0.85}]}}
    live = {"biological_age": {"contributions": [{"term": "fitness"}]}}
    assert not _conforms(live, snap)


# ── Top-level dicts (already covered by the identical-key-set rule; pinned) ──


def test_top_level_dict_key_removal_is_caught() -> None:
    assert not _conforms({"a": 1}, {"a": 1, "b": 2})


def test_top_level_dict_extra_key_is_caught() -> None:
    assert not _conforms({"a": 1, "b": 2}, {"a": 1})


def test_nested_dict_key_removal_is_caught() -> None:
    assert not _conforms({"outer": {"a": 1}}, {"outer": {"a": 1, "b": 2}})


# ── Scalars and scalar lists are unaffected by the union rule ──────────────


def test_scalar_type_mismatch_still_fails() -> None:
    assert not _conforms("41.5", 41.5)
    assert not _conforms(41.5, "41.5")


def test_int_and_float_remain_interchangeable() -> None:
    assert _conforms(41, 41.5)
    assert _conforms(41.5, 41)


def test_bool_is_not_a_number() -> None:
    assert not _conforms(True, 1)


def test_null_on_either_side_is_accepted() -> None:
    assert _conforms(None, 41.5)
    assert _conforms(41.5, None)


def test_scalar_list_element_type_is_checked() -> None:
    assert _conforms([1, 2, 3], [0])
    assert not _conforms(["a"], [0])


def test_wrong_container_type_fails() -> None:
    assert not _conforms({"a": 1}, [{"a": 1}])
    assert not _conforms([{"a": 1}], {"a": 1})
