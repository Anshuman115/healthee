"""The basemap — GET /api/map (what to credit, and the zoom range) and
GET /api/map/tiles/{z}/{x}/{y} (one tile, cached). Thin over `core.map_tiles`.

Authenticated like every other `/api/` route, and for a reason beyond the usual
one: an open tile proxy is somebody else's traffic spent against the provider's
quota under this deployment's name, and the provider's remedy is to block the
deployment. The auth keeps the proxy the owner's own.

**No handler here logs its coordinates or its caller.** That is the whole point
of proxying (see `core/map_tiles`), and the access log is silenced for this
prefix in `api/app.py`.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Response
from pydantic import BaseModel

from healthee.core.config import get_settings
from healthee.core.map_tiles import (
    CLIENT_CACHE_S,
    TILE_PATH_TEMPLATE,
    tile_in_range,
    tile_png,
    zoom_range,
)
from healthee.core.request_auth import CurrentUser

router = APIRouter(tags=["map"])


class MapStyle(BaseModel):
    """What a client needs to draw this deployment's basemap, and to credit it."""

    attribution: str
    min_zoom: int
    max_zoom: int
    tile_path: str


@router.get("/api/map", response_model=MapStyle)
def map_style(_user: CurrentUser) -> MapStyle:
    """The basemap's credit line, its zoom range, and where its tiles live.

    Served rather than compiled into the app because the upstream provider is
    deployment configuration: an operator who repoints `MAP_TILE_URL` changes who
    must be credited, and a build-time attribution string could not follow. The
    app draws no basemap at all when it cannot read this, which is the honest
    failure — a map with nobody credited is not a map we may show.
    """
    low, high = zoom_range()
    return MapStyle(
        attribution=get_settings().map_tile_attribution,
        min_zoom=low,
        max_zoom=high,
        tile_path=TILE_PATH_TEMPLATE,
    )


@router.get("/api/map/tiles/{z}/{x}/{y}")
def map_tile(_user: CurrentUser, z: int, x: int, y: int) -> Response:
    """One basemap tile, from this server's cache, fetched upstream on a miss.

    404 for a tile outside the served zoom range or off the grid — refused here
    rather than forwarded, so a bad request costs the provider nothing. 502 when
    the upstream could not be reached: "we will not serve this" and "we could not
    get this" are different states and the client may not conflate them
    (standards section 1), even though it draws the same plain ground for both.
    """
    if not tile_in_range(z, x, y):
        raise HTTPException(status_code=404, detail="tile out of range")
    data = tile_png(z, x, y)
    if data is None:
        raise HTTPException(status_code=502, detail="basemap upstream unavailable")
    return Response(
        content=data,
        media_type="image/png",
        # `private`: the tile itself is public data, but the request for it is
        # not, and a shared cache keyed on this url would be a location history
        # held by a middlebox.
        headers={"Cache-Control": f"private, max-age={CLIENT_CACHE_S}"},
    )
