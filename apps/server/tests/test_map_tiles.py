"""The basemap proxy: what it refuses, what it caches, and what it never logs.

Three of these are honesty/privacy guarantees rather than behaviour, and they are
the ones that would fail silently:

  * an **out-of-range z/x/y is refused here, never forwarded** — a forwarded one
    still draws nothing in the app, so the only visible difference is on the
    provider's quota and their ban list;
  * a failed tile is logged **without its coordinates**, because a tile log is a
    location history under another name and that is the whole reason the phone
    asks this server rather than the provider;
  * the cache is **bounded**, and an unbounded one looks exactly like a bounded
    one until the disk fills.

Everything here is hermetic: `_fetch` is monkeypatched in every test that would
otherwise reach the network, and the cache is a `tmp_path`.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from healthee.api.app import create_app
from healthee.core import map_tiles
from healthee.core.config import Settings, get_settings
from healthee.core.logging import silence_access_log_for
from healthee.core.request_auth import RequestUser, request_user
from healthee.core.tenancy import SENTINEL_USER_ID

_TILE = b"\x89PNG\r\n\x1a\nnot-really-a-png"


@pytest.fixture
def tile_env(env: None, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:  # noqa: ARG001
    """A hermetic tile cache and a known zoom range."""
    monkeypatch.setenv("MAP_TILE_CACHE_DIR", str(tmp_path / "tiles"))
    monkeypatch.setenv("MAP_TILE_MIN_ZOOM", "2")
    monkeypatch.setenv("MAP_TILE_MAX_ZOOM", "16")
    get_settings.cache_clear()


def _fetches(monkeypatch: pytest.MonkeyPatch, data: bytes | None) -> list[tuple[int, int, int]]:
    """Replace the upstream fetch with a recorder returning [data]."""
    calls: list[tuple[int, int, int]] = []

    def fake(z: int, x: int, y: int) -> bytes | None:
        calls.append((z, x, y))
        return data

    monkeypatch.setattr(map_tiles, "_fetch", fake)
    return calls


# ── the range check ──────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("z", "x", "y"),
    [
        (1, 0, 0),  # below the configured minimum
        (17, 0, 0),  # above the configured maximum
        (2, 4, 0),  # x off the grid: zoom 2 is 4 wide, so 4 is one past the end
        (2, 0, -1),  # y below the grid
    ],
)
def test_a_tile_outside_the_range_is_refused_and_never_forwarded(
    tile_env: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
    z: int,
    x: int,
    y: int,
) -> None:
    """The provider must never see a request we already know is nonsense.

    Forwarding it costs them a lookup and costs us their goodwill, and the app
    draws the same plain ground either way — so the only place the difference is
    visible is somewhere we cannot see, which is why this is a test.
    """
    calls = _fetches(monkeypatch, _TILE)

    assert map_tiles.tile_in_range(z, x, y) is False
    assert calls == []


def test_a_tile_inside_the_range_is_accepted(tile_env: None) -> None:  # noqa: ARG001
    """The corners of the grid are inside it — an off-by-one here loses real tiles."""
    assert map_tiles.tile_in_range(2, 0, 0) is True
    assert map_tiles.tile_in_range(2, 3, 3) is True
    assert map_tiles.tile_in_range(16, (1 << 16) - 1, 0) is True


# ── the cache ────────────────────────────────────────────────────────────────


def test_a_miss_fetches_once_and_a_hit_never_fetches_again(
    tile_env: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The cache is what makes proxying kinder to the provider than not proxying."""
    calls = _fetches(monkeypatch, _TILE)

    assert map_tiles.tile_png(10, 1, 2) == _TILE
    assert map_tiles.tile_png(10, 1, 2) == _TILE

    assert calls == [(10, 1, 2)], "the second read came off disk"


def test_an_upstream_failure_is_not_cached(
    tile_env: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A tile we could not get is not a tile that does not exist.

    Caching the failure would turn one bad minute of network into a permanently
    blank square of the world.
    """
    calls = _fetches(monkeypatch, None)

    assert map_tiles.tile_png(10, 1, 2) is None
    assert map_tiles.tile_png(10, 1, 2) is None

    assert len(calls) == 2


def test_the_sweep_evicts_oldest_first_down_to_the_budget(
    tile_env: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """An unbounded cache looks exactly like a bounded one until the disk fills."""
    monkeypatch.setenv("MAP_TILE_CACHE_MB", "1")
    get_settings.cache_clear()
    root = Path(get_settings().map_tile_cache_dir)
    root.mkdir(parents=True)
    for index in range(20):
        tile = root / f"{index}.png"
        tile.write_bytes(b"x" * 100_000)  # 20 x 100 KB = 2 MB against a 1 MB budget
        os.utime(tile, (index, index))  # oldest first, deterministically

    removed = map_tiles.sweep_cache()

    survivors = sorted(int(p.stem) for p in root.iterdir())
    assert removed > 0
    assert sum(p.stat().st_size for p in root.iterdir()) <= 1024 * 1024 * 0.9
    assert survivors[-1] == 19, "the newest tile is the last one evicted"
    assert 0 not in survivors, "the oldest tile went first"


def test_a_cache_under_budget_is_left_alone(
    tile_env: None,  # noqa: ARG001
) -> None:
    root = Path(get_settings().map_tile_cache_dir)
    root.mkdir(parents=True)
    (root / "one.png").write_bytes(b"x" * 10)

    assert map_tiles.sweep_cache() == 0
    assert (root / "one.png").exists()


# ── what is never logged ─────────────────────────────────────────────────────


def test_a_failed_tile_is_logged_without_its_coordinates(
    tile_env: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """The failure has to be observable; the location must not be.

    `dem.py` logs its tile NAME on the same failure, and that is fine there — a
    1x1-degree cell is a region. A zoom-16 basemap tile is a couple of streets,
    so the same line here would be the location history this whole module exists
    to keep off other people's disks. It would also be the easiest thing in the
    world to add back "for debugging".
    """

    def explode(url: str, timeout: float) -> None:  # noqa: ARG001
        raise OSError("connection refused")

    monkeypatch.setattr(map_tiles.urllib.request, "urlopen", explode)
    with caplog.at_level(logging.WARNING):
        assert map_tiles.tile_png(16, 34567, 21098) is None

    lines = " ".join(record.getMessage() for record in caplog.records)
    assert "unavailable" in lines, "the failure is reported, never swallowed"
    for fragment in ("34567", "21098", "tile.openstreetmap.org"):
        assert fragment not in lines, f"{fragment!r} in a log line is a location log"


def test_the_access_log_filter_drops_tile_lines_and_keeps_the_rest() -> None:
    """uvicorn prints the request path, and this path is the payload."""
    silence_access_log_for(map_tiles.TILE_PATH_PREFIX)
    access = logging.getLogger("uvicorn.access")
    try:
        tile = access.makeRecord(
            "uvicorn.access",
            logging.INFO,
            "",
            0,
            '"GET /api/map/tiles/16/1/2 HTTP/1.1" 200',
            (),
            None,
        )
        other = access.makeRecord(
            "uvicorn.access", logging.INFO, "", 0, '"GET /api/today HTTP/1.1" 200', (), None
        )

        assert all(f.filter(tile) for f in access.filters) is False
        assert all(f.filter(other) for f in access.filters) is True
    finally:
        access.filters.clear()


def test_installing_the_filter_twice_adds_one_filter() -> None:
    """Startup is not the only thing that can call it; two filters is a smell."""
    access = logging.getLogger("uvicorn.access")
    access.filters.clear()
    try:
        silence_access_log_for("/api/map/tiles/")
        silence_access_log_for("/api/map/tiles/")

        assert len(access.filters) == 1
    finally:
        access.filters.clear()


# ── the route ────────────────────────────────────────────────────────────────


@pytest.fixture
def client(tile_env: None) -> TestClient:  # noqa: ARG001
    """The app with an already-resolved owner.

    These tests are about tiles, not identity: resolving a real bearer token
    needs the database, and a tile is not tenant data — nothing under
    `/api/map` reads a row or takes a `tenant_transaction`. The auth is still
    exercised, once, by `test_the_tile_route_needs_the_bearer_token` on an app
    with no override.
    """
    app = create_app()
    app.dependency_overrides[request_user] = lambda: RequestUser(
        id=SENTINEL_USER_ID, timezone="Asia/Kolkata"
    )
    return TestClient(app)


def _auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {get_settings().realtime_ingest_token}"}


def test_the_route_serves_a_cached_tile_as_a_png(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _fetches(monkeypatch, _TILE)

    response = client.get("/api/map/tiles/10/1/2", headers=_auth())

    assert response.status_code == 200
    assert response.content == _TILE
    assert response.headers["content-type"] == "image/png"
    assert "private" in response.headers["cache-control"]


def test_the_route_refuses_an_out_of_range_zoom_without_forwarding_it(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """404, and the provider never hears about it."""
    calls = _fetches(monkeypatch, _TILE)

    assert client.get("/api/map/tiles/22/1/2", headers=_auth()).status_code == 404
    assert client.get("/api/map/tiles/0/0/0", headers=_auth()).status_code == 404
    assert client.get("/api/map/tiles/10/99999999/2", headers=_auth()).status_code == 404
    assert calls == []


def test_an_unreachable_upstream_is_a_502_not_a_404(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """ "We will not serve this" and "we could not get this" are different states."""
    _fetches(monkeypatch, None)

    assert client.get("/api/map/tiles/10/1/2", headers=_auth()).status_code == 502


def test_the_tile_route_needs_the_bearer_token(tile_env: None) -> None:  # noqa: ARG001
    """An open tile proxy is somebody else's traffic on this deployment's name.

    No dependency override here — the point is that the real guard runs, and it
    refuses before anything touches the database or the provider.
    """
    unauthenticated = TestClient(create_app(), raise_server_exceptions=False)

    assert unauthenticated.get("/api/map/tiles/10/1/2").status_code in (401, 403)
    assert unauthenticated.get("/api/map").status_code in (401, 403)


def test_the_style_endpoint_carries_the_attribution_and_the_range(
    client: TestClient,
) -> None:
    """The credit line is served, not compiled in, because the provider is config."""
    body = client.get("/api/map", headers=_auth()).json()

    assert body["attribution"] == get_settings().map_tile_attribution
    assert (body["min_zoom"], body["max_zoom"]) == (2, 16)
    assert body["tile_path"] == "/api/map/tiles/{z}/{x}/{y}"


# ── the template is checked at boot ──────────────────────────────────────────


@pytest.mark.parametrize(
    "url",
    [
        "file:///etc/passwd",
        "https://tiles.example.com/{z}/{x}.png",
        "https://tiles.example.com/static.png",
    ],
)
def test_an_unusable_tile_template_refuses_to_boot(
    env: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
    url: str,
) -> None:
    """A template with no placeholders serves one square of the world forever, and a
    non-http one hands `urlopen` a scheme that reads the filesystem."""
    monkeypatch.setenv("MAP_TILE_URL", url)

    with pytest.raises(ValueError, match="MAP_TILE_URL"):
        Settings()


def test_an_inverted_zoom_range_refuses_to_boot(
    env: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("MAP_TILE_MIN_ZOOM", "12")
    monkeypatch.setenv("MAP_TILE_MAX_ZOOM", "4")

    with pytest.raises(ValueError, match="MAP_TILE_MIN_ZOOM"):
        Settings()
