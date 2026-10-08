# backend/app/modules/network/router.py
from fastapi import APIRouter
from app.modules.network import service

router = APIRouter(prefix="/api/network", tags=["network"])

@router.get("/state")
def network_state():
    return service.get_network_state()

@router.get("/version")
def network_version():
    return service.get_network_version()

@router.get("/history/{road_id}")
def road_history(road_id: int):
    return service.get_road_history(road_id)
