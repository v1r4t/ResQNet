# backend/app/modules/network/router.py
from fastapi import APIRouter, HTTPException
from app.modules.network import service

router = APIRouter(prefix="/api/network", tags=["network"])

@router.get("/state")
def network_state():
    return service.get_network_state()

@router.get("/version")
def network_version():
    result = service.get_network_version()
    if result is None:
        raise HTTPException(status_code=404, detail="No active network version found")
    return result

@router.get("/history/{road_id}")
def road_history(road_id: int):
    return service.get_road_history(road_id)
