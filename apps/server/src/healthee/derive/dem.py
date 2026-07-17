"""Terrain-elevation (DEM) lookup — accurate grade for hilly routes, no barometer.

The phone has GPS but no barometer, so GPS *altitude* is noisy (+/-10-30 m) and
wrecks grade on real hills. Instead we map each GPS lat/lng to a Digital Elevation
Model: a 1x1-degree SRTM HGT tile, bilinearly interpolated. Tiles come from the
no-auth AWS Terrain Tiles (Skadi) public dataset and are cached on disk.

Privacy: we download a 1x1-degree terrain TILE for the region (public elevation
data) and do all lookups LOCALLY — the user's GPS track is never sent anywhere.
Falls back to the caller's GPS elevation when a tile is unavailable.

Ported verbatim from legacy v2 ``dem`` (a proven, dependency-free module). The
only change: the tile-download failure is now logged through the app logger and
narrowed to network/IO/decode errors instead of a bare ``except`` (standards §1 —
errors are never swallowed; a miss is still a meaningful "fall back to GPS
elevation", now observable). Knowledge: [[grade_adjusted_pace]].
"""

from __future__ import annotations

import gzip
import math
import os
import struct
import urllib.error
import urllib.request
from functools import lru_cache

from healthee.core.logging import get_logger

log = get_logger(__name__)

CACHE_DIR = os.environ.get("SRTM_CACHE_DIR", "/tmp/srtm")  # noqa: S108 — public-data tile cache
_BASE = "https://elevation-tiles-prod.s3.amazonaws.com/skadi"
_VOID = -32768
_DOWNLOAD_TIMEOUT_S = 30


def _tile_name(lat: float, lng: float) -> str:
    """SRTM tile name (e.g. N28E077) covering the 1-degree cell of lat/lng."""
    la = int(math.floor(lat))
    lo = int(math.floor(lng))
    return f"{'N' if la >= 0 else 'S'}{abs(la):02d}{'E' if lo >= 0 else 'W'}{abs(lo):03d}"


@lru_cache(maxsize=8)
def _load_tile(name: str) -> tuple[bytes, int] | None:
    """(raw int16 grid, side length) for a tile — download+cache if needed.

    None when the tile is unavailable (missing over ocean, or the download failed
    — logged), so the caller falls back to GPS elevation.
    """
    path = os.path.join(CACHE_DIR, name + ".hgt")
    if not os.path.exists(path) and not _download_tile(name, path):
        return None
    with open(path, "rb") as handle:
        raw = handle.read()
    n = len(raw) // 2
    size = int(round(math.sqrt(n)))
    return (raw, size) if size * size == n else None


def _download_tile(name: str, path: str) -> bool:
    """Fetch+cache one gzip HGT tile. False (logged) on any network/IO/decode error."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    url = f"{_BASE}/{name[:3]}/{name}.hgt.gz"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "healthee-dem/1"})
        with urllib.request.urlopen(req, timeout=_DOWNLOAD_TIMEOUT_S) as r:  # noqa: S310 — https literal
            data = gzip.decompress(r.read())
        with open(path, "wb") as f:
            f.write(data)
    except (OSError, urllib.error.URLError, EOFError, gzip.BadGzipFile) as exc:
        log.warning("DEM tile %s unavailable (%s) — falling back to GPS elevation", name, exc)
        return False
    return True


def elevation(lat: float, lng: float) -> float | None:
    """Bilinear-interpolated terrain elevation in metres, or None if unavailable/void."""
    tile = _load_tile(_tile_name(lat, lng))
    if tile is None:
        return None
    raw, size = tile
    la = math.floor(lat)
    lo = math.floor(lng)
    # HGT is row-major from the NW corner: row 0 = north edge (lat+1), col 0 = west (lo).
    y = (la + 1 - lat) * (size - 1)
    x = (lng - lo) * (size - 1)
    r0, c0 = int(math.floor(y)), int(math.floor(x))
    r1, c1 = min(r0 + 1, size - 1), min(c0 + 1, size - 1)
    fy, fx = y - r0, x - c0

    def px(r: int, c: int) -> int | None:
        v = struct.unpack_from(">h", raw, (r * size + c) * 2)[0]
        return None if v == _VOID else v

    v00, v01, v10, v11 = px(r0, c0), px(r0, c1), px(r1, c0), px(r1, c1)
    corners = [v for v in (v00, v01, v10, v11) if v is not None]
    if not corners:
        return None
    if v00 is None or v01 is None or v10 is None or v11 is None:
        return sum(corners) / len(corners)  # some voids — fall back to the valid-corner mean
    top = v00 * (1 - fx) + v01 * fx
    bot = v10 * (1 - fx) + v11 * fx
    return top * (1 - fy) + bot * fy


def elevations(coords: list[tuple[float, float]]) -> tuple[list[float | None], int]:
    """Look up many points. Returns (elevations, n_hits). Tiles cached across the batch."""
    out = [elevation(la, lo) for la, lo in coords]
    return out, sum(1 for e in out if e is not None)
