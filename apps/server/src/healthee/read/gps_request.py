"""Bounded, validated phone route uploads with an optional stable client identity."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


class GpsTrackIn(BaseModel):
    model_config = ConfigDict(allow_inf_nan=False)
    start_iso: str
    end_iso: str
    points: list[list[float | None]] = Field(max_length=28800)
    client_id: UUID | None = None

    @model_validator(mode="after")
    def valid_route(self) -> GpsTrackIn:
        start, end = datetime.fromisoformat(self.start_iso), datetime.fromisoformat(self.end_iso)
        if start.tzinfo is None or end.tzinfo is None or end <= start:
            raise ValueError("route requires an ordered window with timezone offsets")
        previous = float("-inf")
        for point in self.points:
            if len(point) not in (3, 4) or any(value is None for value in point[:3]):
                raise ValueError(
                    "points require timestamp, latitude, longitude, optional elevation"
                )
            timestamp, lat, lng = point[:3]
            assert timestamp is not None and lat is not None and lng is not None
            if not (-90 <= lat <= 90 and -180 <= lng <= 180):
                raise ValueError("invalid GPS coordinates")
            if not start.timestamp() <= timestamp <= end.timestamp() or timestamp <= previous:
                raise ValueError("GPS timestamps must increase within the recording window")
            previous = timestamp
        return self
