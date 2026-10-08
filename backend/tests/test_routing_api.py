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

def test_recalculate_routes():
    response = client.post("/api/routes/recalculate")
    assert response.status_code == 200
    assert "recalculated" in response.json()
