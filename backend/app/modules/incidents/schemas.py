# backend/app/modules/incidents/schemas.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class IncidentReportInput(BaseModel):
    raw_text: str

class ManualIncidentInput(BaseModel):
    type: str
    severity: str
    road: str
    lanes_blocked: int = 1
    description: str = ""

class IncidentResponse(BaseModel):
    id: int
    type: str
    severity: str
    status: str
    description: Optional[str]
    started_at: datetime
    cleared_at: Optional[datetime]

class IncidentReportResponse(BaseModel):
    report_id: int
    incident_id: int
    extracted_data: dict
    extraction_source: str
    extraction_fallback: bool
    affected_roads: list[int]
