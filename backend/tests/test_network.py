# backend/tests/test_network.py
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_network_state():
    response = client.get("/api/network/state")
    assert response.status_code == 200
    assert "roads" in response.json()
    assert "intersections" in response.json()

def test_network_version():
    response = client.get("/api/network/version")
    assert response.status_code == 200
    assert "id" in response.json()

def test_road_history():
    response = client.get("/api/network/history/1")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
