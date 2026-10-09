# backend/app/modules/incidents/router.py
from fastapi import APIRouter, Query, HTTPException
from app.modules.incidents.schemas import IncidentReportInput, ManualIncidentInput, IncidentResponse
from app.modules.incidents import service

router = APIRouter(prefix="/api/incidents", tags=["incidents"])

@router.post("/report")
def submit_report(input: IncidentReportInput):
    try:
        return service.submit_report(input.raw_text)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

@router.post("/manual")
def create_manual(input: ManualIncidentInput):
    try:
        return service.create_manual_incident(input)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("")
def list_incidents(
    status: str = Query(None),
    severity: str = Query(None),
    zone_id: int = Query(None)
):
    return service.get_incidents(status, severity, zone_id)

@router.get("/history")
def incident_history():
    return service.get_incident_history()

@router.get("/nearby")
def nearby_incidents(lat: float = Query(...), lon: float = Query(...), radius_m: float = Query(1000)):
    return service.get_nearby_incidents(lat, lon, radius_m)

@router.get("/{incident_id}")
def get_incident(incident_id: int):
    result = service.get_incident_by_id(incident_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Incident {incident_id} not found")
    return result

@router.post("/{incident_id}/clear")
def clear_incident(incident_id: int):
    try:
        return service.clear_incident(incident_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
