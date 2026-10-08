# backend/app/modules/vehicles/router.py
from fastapi import APIRouter, Query
from app.modules.vehicles.schemas import VehicleCreate, VehicleLocationUpdate
from app.modules.vehicles import service

router = APIRouter(prefix="/api/vehicles", tags=["vehicles"])

@router.get("")
def list_vehicles(
    vehicle_type: str = Query(None),
    status: str = Query(None),
    zone_id: int = Query(None)
):
    return service.get_vehicles(vehicle_type, status, zone_id)

@router.get("/status")
def vehicle_status():
    return service.get_vehicle_status_summary()

@router.post("")
def create_vehicle(vehicle: VehicleCreate):
    pass

@router.patch("/{vehicle_id}/location")
def update_location(vehicle_id: int, update: VehicleLocationUpdate):
    return service.update_vehicle_location(vehicle_id, update.current_intersection_id)

@router.get("/nearest")
def nearest_vehicle(intersection_id: int = Query(...), vehicle_type: str = Query(...)):
    return service.get_nearest_vehicle(intersection_id, vehicle_type)
