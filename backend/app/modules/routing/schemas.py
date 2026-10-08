# backend/app/modules/routing/schemas.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class RouteRequestInput(BaseModel):
    vehicle_id: Optional[int] = None
    origin_id: int
    destination_id: int
    priority: int = 5

class RouteSegmentResponse(BaseModel):
    sequence_order: int
    road_segment_id: int
    road_name: str
    estimated_time_min: float

class RouteResponse(BaseModel):
    id: int
    request_id: int
    route_type: str
    total_time_min: float
    total_distance_m: float
    status: str
    network_version_id: Optional[int]
    created_at: datetime
    segments: list[RouteSegmentResponse]
