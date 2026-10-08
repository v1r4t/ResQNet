# backend/app/modules/routing/router.py
from fastapi import APIRouter
from app.modules.routing.schemas import RouteRequestInput, RouteResponse
from app.modules.routing import service

router = APIRouter(prefix="/api/routes", tags=["routing"])

@router.post("/request")
def request_route(input: RouteRequestInput):
    return service.calculate_route(input.origin_id, input.destination_id, input.vehicle_id)

@router.post("/recalculate")
def recalculate():
    return service.recalculate_routes()

@router.get("/{route_id}")
def get_route(route_id: int):
    pass

@router.get("/request/{request_id}")
def get_request_routes(request_id: int):
    pass

@router.post("/{route_id}/complete")
def complete_route(route_id: int, actual_time_min: float):
    pass

@router.get("/affected/{road_id}")
def get_affected_routes(road_id: int):
    pass
