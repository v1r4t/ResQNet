# backend/tests/test_routing_api.py
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_request_route():
    response = client.post("/api/routes/request", json={
        "origin_id": 1,
        "destination_id": 10,
        "priority": 5
    })
    assert response.status_code == 200
    data = response.json()
    assert "route_id" in data
    assert data["total_time_min"] > 0

def test_request_route_not_found():
    response = client.post("/api/routes/request", json={
        "origin_id": 99999,
        "destination_id": 88888,
        "priority": 5
    })
    assert response.status_code == 404

def test_recalculate_routes():
    response = client.post("/api/routes/recalculate")
    assert response.status_code == 200
    assert "recalculated" in response.json()

def test_get_route():
    # First create a route
    create_response = client.post("/api/routes/request", json={
        "origin_id": 1,
        "destination_id": 10,
        "priority": 5
    })
    assert create_response.status_code == 200
    route_id = create_response.json()["route_id"]

    # Get the route
    response = client.get(f"/api/routes/{route_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == route_id
    assert "segments" in data
    assert len(data["segments"]) > 0

def test_get_route_not_found():
    response = client.get("/api/routes/99999")
    assert response.status_code == 404

def test_get_request_routes():
    # First create a route
    create_response = client.post("/api/routes/request", json={
        "origin_id": 1,
        "destination_id": 10,
        "priority": 5
    })
    assert create_response.status_code == 200
    request_id = create_response.json()["request_id"]

    # Get routes for the request
    response = client.get(f"/api/routes/request/{request_id}")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0

def test_complete_route():
    # First create a route
    create_response = client.post("/api/routes/request", json={
        "origin_id": 1,
        "destination_id": 10,
        "priority": 5
    })
    assert create_response.status_code == 200
    route_id = create_response.json()["route_id"]

    # Complete the route
    response = client.post(f"/api/routes/{route_id}/complete?actual_time_min=15.5")
    assert response.status_code == 200
    data = response.json()
    assert data["route_id"] == route_id
    assert data["status"] == "completed"

def test_complete_route_not_found():
    response = client.post("/api/routes/99999/complete?actual_time_min=15.5")
    assert response.status_code == 404

def test_get_affected_routes():
    response = client.get("/api/routes/affected/1")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
