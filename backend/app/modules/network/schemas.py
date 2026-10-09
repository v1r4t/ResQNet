# backend/app/modules/network/schemas.py
from pydantic import BaseModel
from typing import Optional

class NetworkStateResponse(BaseModel):
    roads: list[dict]
    intersections: list[dict]
    routes: list[dict] = []

class NetworkVersionResponse(BaseModel):
    id: int
    created_at: str
    is_active: bool

class RoadHistoryResponse(BaseModel):
    id: int
    road_segment_id: int
    old_travel_time: float
    new_travel_time: float
    change_reason: str
    changed_at: str
