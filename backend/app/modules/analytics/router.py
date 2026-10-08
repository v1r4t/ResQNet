# backend/app/modules/analytics/router.py
from fastapi import APIRouter
from app.modules.analytics import service

router = APIRouter(prefix="/api/analytics", tags=["analytics"])

@router.get("/congestion")
def congestion():
    return service.get_congestion_hotspots()

@router.get("/incident-frequency")
def incident_frequency():
    return service.get_incident_frequency()

@router.get("/route-performance")
def route_performance():
    return service.get_route_performance()

@router.get("/response-times")
def response_times():
    return service.get_response_times()

@router.get("/explain/{query_id}")
def explain(query_id: str):
    return service.get_explain_plan(query_id)
