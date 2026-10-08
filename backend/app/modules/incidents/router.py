# backend/app/modules/incidents/router.py
from fastapi import APIRouter, Query
from app.modules.incidents.schemas import IncidentReportInput, ManualIncidentInput, IncidentResponse
from app.modules.incidents import service

router = APIRouter(prefix="/api/incidents", tags=["incidents"])

@router.post("/report")
def submit_report(input: IncidentReportInput):
    return service.submit_report(input.raw_text)

@router.post("/manual")
def create_manual(input: ManualIncidentInput):
    return service.create_manual_incident(input)

@router.get("")
def list_incidents(
    status: str = Query(None),
    severity: str = Query(None),
    zone_id: int = Query(None)
):
    return service.get_incidents(status, severity, zone_id)

@router.get("/history")
def incident_history():
    return service.get_incidents()

@router.post("/{incident_id}/clear")
def clear_incident(incident_id: int):
    return service.clear_incident(incident_id)

@router.get("/nearby")
def nearby_incidents(lat: float = Query(...), lon: float = Query(...), radius_m: float = Query(1000)):
    # PostGIS spatial query
    pass
