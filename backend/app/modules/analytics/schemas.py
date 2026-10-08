# backend/app/modules/analytics/schemas.py
from pydantic import BaseModel
from typing import Optional

class CongestionHotspot(BaseModel):
    zone_name: str
    hotspot_count: int
    avg_travel_time: float
    avg_congestion_ratio: float

class IncidentFrequency(BaseModel):
    road_segment_id: int
    road_name: str
    incident_type: str
    incident_count: int
    day: str

class RoutePerformance(BaseModel):
    route_id: int
    route_type: str
    estimated_time: float
    actual_time_min: Optional[float]
    performance_delta: Optional[float]
    status: str
    vehicle_type: str
    created_at: str

class ExplainPlanResponse(BaseModel):
    query_id: str
    plan: list[str]
