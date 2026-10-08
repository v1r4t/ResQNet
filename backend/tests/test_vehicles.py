# backend/tests/test_vehicles.py
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_list_vehicles():
    response = client.get("/api/vehicles")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_vehicle_status():
    response = client.get("/api/vehicles/status")
    assert response.status_code == 200
    assert isinstance(response.json(), dict)

def test_nearest_vehicle():
    response = client.get("/api/vehicles/nearest?intersection_id=1&vehicle_type=ambulance")
    assert response.status_code == 200
