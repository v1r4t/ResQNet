# backend/tests/test_vehicles.py
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_list_vehicles():
    response = client.get("/api/vehicles")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_list_vehicles_includes_zone():
    # I2: current_zone_id must be present in the selected columns
    response = client.get("/api/vehicles")
    assert response.status_code == 200
    data = response.json()
    for vehicle in data:
        assert "current_zone_id" in vehicle

def test_list_vehicles_filter_by_zone():
    response = client.get("/api/vehicles?zone_id=1")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    for vehicle in data:
        assert vehicle["current_zone_id"] == 1

def test_vehicle_status():
    response = client.get("/api/vehicles/status")
    assert response.status_code == 200
    assert isinstance(response.json(), dict)

def test_create_vehicle():
    # C1: create endpoint must return the new vehicle, not null
    response = client.post("/api/vehicles", json={
        "vehicle_type": "ambulance",
        "name": "Test Ambulance",
        "current_intersection_id": 1
    })
    assert response.status_code == 200
    data = response.json()
    assert "id" in data
    assert data["id"] is not None
    assert data["vehicle_type"] == "ambulance"
    assert data["name"] == "Test Ambulance"

def test_create_vehicle_invalid_intersection():
    response = client.post("/api/vehicles", json={
        "vehicle_type": "ambulance",
        "name": "Bad Vehicle",
        "current_intersection_id": 99999
    })
    assert response.status_code == 400

def test_update_vehicle_location():
    create_response = client.post("/api/vehicles", json={
        "vehicle_type": "police",
        "name": "Test Police",
        "current_intersection_id": 1
    })
    assert create_response.status_code == 200
    vehicle_id = create_response.json()["id"]

    response = client.patch(f"/api/vehicles/{vehicle_id}/location", json={
        "current_intersection_id": 2
    })
    assert response.status_code == 200
    data = response.json()
    assert data["vehicle_id"] == vehicle_id
    assert data["current_intersection_id"] == 2

def test_update_vehicle_location_not_found():
    # I3: updating a non-existent vehicle must not report success
    response = client.patch("/api/vehicles/99999/location", json={
        "current_intersection_id": 2
    })
    assert response.status_code == 404

def test_nearest_vehicle():
    response = client.get("/api/vehicles/nearest?intersection_id=1&vehicle_type=ambulance")
    assert response.status_code == 200

def test_nearest_vehicle_distance_in_meters():
    # I1: distance must be reported in meters, not degrees.
    # Fire-1 sits at intersection 28, far from intersection 1, so a
    # meter-based distance is in the thousands while a degree-based
    # distance would be < 1.
    response = client.get("/api/vehicles/nearest?intersection_id=1&vehicle_type=fire_engine")
    assert response.status_code == 200
    data = response.json()
    assert data is not None
    assert data["distance_m"] > 100
