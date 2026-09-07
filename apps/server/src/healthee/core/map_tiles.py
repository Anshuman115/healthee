"""Basemap tiles — fetched by THIS server, cached on disk, served to the app.

The phone never talks to a tile provider. A tile request is a statement about
where somebody is looking, and a provider serving a phone directly learns the
streets the owner runs on, at what times, from what IP. `derive/dem.py` already
settled the shape of that problem for this product:

    "we download a 1x1-degree terrain TILE for the region (public elevation
    data) and do all lookups LOCALLY — the user's GPS track is never sent
    anywhere."

This is that argument applied to the basemap. The provider sees this server ask
for a square of the world; it cannot see whose track crosses it, or that any
track crosses it at all, and after the first fetch it does not see the ask again.

It is also the shape OpenStreetMap's tile usage policy sanctions: their public
servers ask applications not to point at them directly, and permit a single
cached server sending a real, identifying `User-Agent` — which is what
`_USER_AGENT` below is for, exactly as `dem.py` sends one.

## Nothing here is logged with its coordinates

A tile log is a location history under another name, so the whole point of
proxying is defeated by an access line. Failures are reported WITHOUT the tile
that failed: no z/x/y, no caller, no upstream url (which contains them). uvicorn
would otherwise print the path on every request, so `api/app.py` installs
`core.logging.silence_access_log_for(TILE_PATH_PREFIX)` at startup, and the
nginx vhost turns `access_log off` for the same prefix.

## The cache is bounded, and the sweep is not per-request

Eviction is oldest-first by mtime down to 90% of the budget. Walking the cache
costs an `os.stat` per file, so it runs once every `_SWEEP_EVERY` stores rather
than on every miss: at 512 MB of ~15 KB tiles the directory holds tens of
thousands of entries, and a walk on the request path would blow the p95 budget
(standards section 1) for a bound that is not that urgent. Overshoot between
sweeps is at most `_SWEEP_EVERY` tiles.
"""

from __future__ import annotations

import os
import urllib.error
import urllib.request

from healthee.core.config import get_settings
from healthee.core.logging import get_logger

log = get_logger(__name__)

#: The url prefix the tile route is mounted at. Exported so the access-log
#: filter and the router cannot drift apart about what must not be logged.
TILE_PATH_PREFIX = "/api/map/tiles/"

#: What the app is told to request. One placeholder set, one definition.
TILE_PATH_TEMPLATE = TILE_PATH_PREFIX + "{z}/{x}/{y}"

#: Identifies this deployment to the provider, as their policy requires and as
#: `dem.py` already does for elevation.
_USER_AGENT = "healthee-basemap/1 (+https://github.com/healthee; self-hosted health companion)"

#: One upstream fetch. Short: a tile that is slow is a tile the app draws the
#: plain ground instead of, which is a normal state here.
_FETCH_TIMEOUT_S = 10

#: A raster tile is a few KB. Anything past this is not a tile, and reading it
#: into memory unbounded is how a hostile or misconfigured upstream ends the
#: process. Read one byte past the cap so the overflow is detectable.
_MAX_TILE_BYTES = 2_000_000

#: Stores between cache sweeps — see the module docstring.
_SWEEP_EVERY = 256

#: How long the app may keep a tile. Tiles change on the scale of weeks and a
#: stale one is a slightly old building, never a wrong measurement.
CLIENT_CACHE_S = 7 * 24 * 3600

_stores_since_sweep = 0


def zoom_range() -> tuple[int, int]:
    """The (min, max) zoom this server will serve, from config."""
    settings = get_settings()
    return settings.map_tile_min_zoom, settings.map_tile_max_zoom


def tile_in_range(z: int, x: int, y: int) -> bool:
    """True when z/x/y names a tile that can exist and that we agreed to serve.

    Checked BEFORE any upstream call, so an out-of-range request costs the
    provider nothing: at zoom z the grid is 2^z squares on a side, and an x or y
    outside it names no place at all.
    """
    low, high = zoom_range()
    if not low <= z <= high:
        return False
    side = 1 << z
    return 0 <= x < side and 0 <= y < side


def tile_png(z: int, x: int, y: int) -> bytes | None:
    """One tile's bytes, from the disk cache, fetching upstream on a miss.

    None when the tile could not be had — the app draws its track on the plain
    ground, which is a normal state and never a blank screen. Callers must have
    checked [tile_in_range] first; this function does not forward what the range
    check would have refused.
    """
    path = _cache_path(z, x, y)
    cached = _read(path)
    if cached is not None:
        return cached
    data = _fetch(z, x, y)
    if data is not None:
        _store(path, data)
    return data


def _cache_path(z: int, x: int, y: int) -> str:
    """`<cache>/<z>/<x>/<y>.png`. Nested so no directory holds 4^z entries."""
    return os.path.join(get_settings().map_tile_cache_dir, str(z), str(x), f"{y}.png")


def _read(path: str) -> bytes | None:
    """The cached tile, or None. A miss and an unreadable cache are both a miss.

    They are logged differently on purpose: a missing file is the ordinary case
    and says nothing, while an unreadable one is a broken cache directory and is
    a warning — without the path, which carries the coordinates.
    """
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except FileNotFoundError:
        return None
    except OSError as exc:
        log.warning("basemap cache unreadable (%s) — refetching", exc.__class__.__name__)
        return None


def _fetch(z: int, x: int, y: int) -> bytes | None:
    """Fetch one tile upstream. None (logged, without coordinates) on failure."""
    url = get_settings().map_tile_url.format(z=z, x=x, y=y)
    try:
        request = urllib.request.Request(url, headers={"User-Agent": _USER_AGENT})
        with urllib.request.urlopen(request, timeout=_FETCH_TIMEOUT_S) as response:  # noqa: S310
            data = response.read(_MAX_TILE_BYTES + 1)
    except (OSError, urllib.error.URLError) as exc:
        # No url, no z/x/y, no caller: the class name and message are what makes
        # this diagnosable, and the coordinates are what makes it a location log.
        log.warning(
            "basemap upstream unavailable (%s) — the app draws the plain ground",
            exc.__class__.__name__,
        )
        return None
    if len(data) > _MAX_TILE_BYTES:
        log.warning("basemap upstream returned more than %d bytes — discarded", _MAX_TILE_BYTES)
        return None
    return data


def _store(path: str, data: bytes) -> None:
    """Write a tile into the cache atomically, then sweep if it is time.

    Atomically because the api and the scheduler share this directory: a reader
    must never see a half-written tile, and `os.replace` is what makes the file
    appear whole or not at all. A cache that cannot be written is logged and the
    tile is still served — the response the caller is waiting for does not depend
    on the cache succeeding.
    """
    temporary = f"{path}.{os.getpid()}.part"
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(temporary, "wb") as handle:
            handle.write(data)
        os.replace(temporary, path)
    except OSError as exc:
        log.warning(
            "basemap cache unwritable (%s) — serving without caching",
            exc.__class__.__name__,
        )
        return
    global _stores_since_sweep
    _stores_since_sweep += 1
    if _stores_since_sweep >= _SWEEP_EVERY:
        _stores_since_sweep = 0
        sweep_cache()


def sweep_cache() -> int:
    """Evict oldest-first until the cache is under 90% of its budget.

    Returns the number of files removed. Public because a bound nobody can ask
    about is a bound nobody can test; the tests drive it directly rather than by
    storing `_SWEEP_EVERY` tiles.
    """
    budget = get_settings().map_tile_cache_mb * 1024 * 1024
    try:
        entries = _cache_entries()
    except OSError as exc:
        log.warning("basemap cache unscannable (%s) — not evicting", exc.__class__.__name__)
        return 0
    total = sum(size for _mtime, size, _path in entries)
    if total <= budget:
        return 0
    entries.sort()
    target = int(budget * 0.9)
    removed = 0
    for _mtime, size, path in entries:
        if total <= target:
            break
        try:
            os.remove(path)
        except OSError:
            continue  # already gone, or the other container took it — not an error
        total -= size
        removed += 1
    log.info("basemap cache swept: %d tiles evicted, %d bytes remain", removed, total)
    return removed


def _cache_entries() -> list[tuple[float, int, str]]:
    """(mtime, size, path) for every cached tile."""
    root = get_settings().map_tile_cache_dir
    found: list[tuple[float, int, str]] = []
    for directory, _subdirectories, names in os.walk(root):
        for name in names:
            path = os.path.join(directory, name)
            try:
                stat = os.stat(path)
            except OSError:
                continue  # raced with another sweep; it is gone either way
            found.append((stat.st_mtime, stat.st_size, path))
    return found
