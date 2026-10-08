# backend/app/modules/vehicles/schemas.py
from pydantic import BaseModel
from typing import Optional

class VehicleCreate(BaseModel):
    vehicle_type: str
    name: str
    current_intersection_id: int

class VehicleLocationUpdate(BaseModel):
    current_intersection_id: int

class VehicleResponse(BaseModel):
    id: int
    vehicle_type: str
    name: str
    status: str
    current_intersection_id: Optional[int]
