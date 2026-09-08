"""Structural conformance: assert a live JSON response has the SAME keys and value
TYPES as a committed snapshot. Values may vary (the DB is re-seeded per run); only
structure is enforced here — exact deterministic numbers are asserted separately in
the contract test.

Rules:
- dicts: identical key set (recursively); a missing or extra key fails.
- lists of objects: heterogeneous/union lists are supported, so the check is a pair
  of rules rather than key equality:
    * per element — a live element's keys must be a SUBSET of the union of keys
      across all snapshot elements, and each field may take ANY type observed for
      that field across the snapshot elements (so a ``target`` that is a number in
      one element and a string in another is accepted);
    * across the list — the union of keys over ALL live elements must COVER the
      union over all snapshot elements.
  The subset rule alone cannot see a dropped field: remove a key from every element
  and the elements are still a subset, so the contract passes while the app breaks.
  The union rule closes that hole without breaking union lists — an element type
  that legitimately lacks a field contributes it from some OTHER element, so the
  union still covers; a removal shrinks the union and fails. This is sound because
  the snapshots are generated from the same deterministic seed the test re-seeds
  (``tests/contracts/generate.py``), so the live element mix is reproducible.
  An EMPTY live list is exempt: no elements means no union, and an empty list is
  legitimate on a real dataset.
- lists of scalars: each element matches the first snapshot element's type.
- scalars: ``int``/``float`` interchangeable (JSON numbers); ``None`` on either side
  is accepted (a real dataset legitimately has null fields).
"""

from __future__ import annotations

from typing import Any


def assert_conforms(live: Any, snap: Any, path: str = "") -> None:
    """Raise AssertionError if ``live`` does not structurally match ``snap``."""
    if snap is None or live is None:
        return  # nullable field — either side may be null in a real dataset
    if isinstance(snap, dict):
        _assert_dict(live, snap, path)
    elif isinstance(snap, list):
        _assert_list(live, snap, path)
    else:
        _assert_scalar(live, snap, path)


def _assert_dict(live: Any, snap: dict, path: str) -> None:
    assert isinstance(live, dict), f"{path}: expected object, got {type(live).__name__}"
    missing = set(snap) - set(live)
    extra = set(live) - set(snap)
    assert not missing, f"{path}: missing keys {sorted(missing)}"
    assert not extra, f"{path}: unexpected keys {sorted(extra)}"
    for key, sub in snap.items():
        assert_conforms(live[key], sub, f"{path}.{key}")


def _assert_list(live: Any, snap: list, path: str) -> None:
    assert isinstance(live, list), f"{path}: expected array, got {type(live).__name__}"
    if not snap:
        return  # no representative element to check against
    if all(isinstance(e, dict) for e in snap):
        _assert_object_list(live, snap, path)
    else:
        for i, item in enumerate(live):
            assert_conforms(item, snap[0], f"{path}[{i}]")


def _assert_object_list(live: list, snap: list[dict], path: str) -> None:
    """Union-shape check: every live object's keys ⊆ the union of snapshot keys, each
    field takes any type observed for it across the snapshot elements, and the live
    union COVERS the snapshot union (see the module docstring for why both rules)."""
    union_keys = set().union(*(set(e) for e in snap))
    samples: dict[str, list] = {}
    for element in snap:
        for key, value in element.items():
            samples.setdefault(key, []).append(value)
    for i, item in enumerate(live):
        assert isinstance(item, dict), f"{path}[{i}]: expected object, got {type(item).__name__}"
        extra = set(item) - union_keys
        assert not extra, f"{path}[{i}]: unexpected keys {sorted(extra)}"
        for key, value in item.items():
            _assert_against_samples(value, samples[key], f"{path}[{i}].{key}")
    _assert_live_union_covers(live, union_keys, path)


def _assert_live_union_covers(live: list, union_keys: set[str], path: str) -> None:
    """Every field the snapshot carries must appear on at least one live element.

    This is the rule that catches a field the server silently DROPPED from a list
    element — the per-element subset rule never can. Empty live lists are exempt:
    an empty list is legitimate on a real dataset, not a dropped field.
    """
    if not live:
        return
    live_union: set[str] = set().union(*(set(e) for e in live))
    dropped = union_keys - live_union
    assert not dropped, (
        f"{path}: field(s) {sorted(dropped)} are in the snapshot but on NO live element "
        f"— the server dropped them from this list"
    )


def _tag(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int | float):
        return "number"
    if isinstance(value, str):
        return "string"
    return "object" if isinstance(value, dict) else "array"


def _assert_against_samples(value: Any, samples: list, path: str) -> None:
    """A field may take any (non-null) SHAPE seen for it across snapshot elements.

    Structured values are checked against every same-typed sample and pass if ANY of them
    conforms, rather than against the first one found. The union rule this function
    implements was already the contract for the object list itself ("each field takes any
    type observed for it"); it stopped one level short, and the first nested object whose
    shape genuinely varies per element broke it.

    That object is ``metrics[].provenance`` — WHICH instrument produced a card's number
    and what it was assembled from. A step count names a source and a sample count, a
    calorie total names its BMR and workout split, and a resting heart rate has nothing to
    say. Those are different facts about different metrics, not one shape with holes, and
    flattening them into a fixed key set with nulls would mean publishing "no workout
    calories" on a step card. So the checker generalises instead.
    """
    if value is None:
        return
    allowed = {_tag(s) for s in samples if s is not None}
    if not allowed:
        return  # every snapshot value for this field was null → accept anything
    assert _tag(value) in allowed, f"{path}: type {_tag(value)} not in {sorted(allowed)}"
    if isinstance(value, dict | list):
        _assert_any_sample_conforms(value, samples, path)


def _assert_any_sample_conforms(value: Any, samples: list, path: str) -> None:
    """Pass if ``value`` conforms to at least one same-typed sample; else re-raise the
    first failure, so the message names a real mismatch rather than "none of N matched"."""
    first: AssertionError | None = None
    for sample in samples:
        if _tag(sample) != _tag(value):
            continue
        try:
            assert_conforms(value, sample, path)
        except AssertionError as exc:  # try the next sample; keep the first explanation
            first = first or exc
        else:
            return
    if first is not None:
        raise first


def _assert_scalar(live: Any, snap: Any, path: str) -> None:
    if isinstance(snap, bool):  # bool before int (bool is a subclass of int)
        assert isinstance(live, bool), f"{path}: expected bool, got {type(live).__name__}"
    elif isinstance(snap, int | float):
        assert isinstance(live, int | float) and not isinstance(live, bool), (
            f"{path}: expected number, got {type(live).__name__}"
        )
    elif isinstance(snap, str):
        assert isinstance(live, str), f"{path}: expected string, got {type(live).__name__}"
