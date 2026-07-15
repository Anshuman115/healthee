"""Structural conformance: assert a live JSON response has the SAME keys and value
TYPES as a committed snapshot. Values may vary (the DB is re-seeded per run); only
structure is enforced here — exact deterministic numbers are asserted separately in
the contract test.

Rules:
- dicts: identical key set (recursively); a missing or extra key fails.
- lists of objects: heterogeneous/union lists are supported — a live element's keys
  must be a subset of the UNION of keys across all snapshot elements, and each field
  may take ANY type observed for that field across the snapshot elements (so a
  ``target`` that is a number in one element and a string in another is accepted).
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
    """Union-shape check: every live object's keys ⊆ the union of snapshot keys, and
    each field takes any type observed for it across the snapshot elements."""
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
    """A field may take any (non-null) type seen for it across snapshot elements."""
    if value is None:
        return
    allowed = {_tag(s) for s in samples if s is not None}
    if not allowed:
        return  # every snapshot value for this field was null → accept anything
    assert _tag(value) in allowed, f"{path}: type {_tag(value)} not in {sorted(allowed)}"
    if isinstance(value, dict | list):
        representative = next(s for s in samples if _tag(s) == _tag(value))
        assert_conforms(value, representative, path)


def _assert_scalar(live: Any, snap: Any, path: str) -> None:
    if isinstance(snap, bool):  # bool before int (bool is a subclass of int)
        assert isinstance(live, bool), f"{path}: expected bool, got {type(live).__name__}"
    elif isinstance(snap, int | float):
        assert isinstance(live, int | float) and not isinstance(live, bool), (
            f"{path}: expected number, got {type(live).__name__}"
        )
    elif isinstance(snap, str):
        assert isinstance(live, str), f"{path}: expected string, got {type(live).__name__}"
