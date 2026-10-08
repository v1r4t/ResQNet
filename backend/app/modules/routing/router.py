# backend/app/modules/routing/router.py
from fastapi import APIRouter, HTTPException
from app.modules.routing.schemas import RouteRequestInput, RouteResponse
from app.modules.routing import service

router = APIRouter(prefix="/api/routes", tags=["routing"])

@router.post("/request")
def request_route(input: RouteRequestInput):
    result = service.calculate_route(input.origin_id, input.destination_id, input.vehicle_id, input.priority)
    if result is None:
        raise HTTPException(status_code=404, detail="No path found between origin and destination")
    return result

@router.post("/recalculate")
def recalculate():
    return service.recalculate_routes()

@router.get("/{route_id}")
def get_route(route_id: int):
    result = service.get_route(route_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Route {route_id} not found")
    return result

@router.get("/request/{request_id}")
def get_request_routes(request_id: int):
    return service.get_request_routes(request_id)

@router.post("/{route_id}/complete")
def complete_route(route_id: int, actual_time_min: float):
    result = service.complete_route(route_id, actual_time_min)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Route {route_id} not found")
    return result

@router.get("/affected/{road_id}")
def get_affected_routes(road_id: int):
    return service.get_affected_routes(road_id)
