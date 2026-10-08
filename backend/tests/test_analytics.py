# backend/tests/test_analytics.py
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_congestion():
    response = client.get("/api/analytics/congestion")
    assert response.status_code == 200

def test_explain_whitelist():
    response = client.get("/api/analytics/explain/nearest_vehicle")
    assert response.status_code == 200
    assert "plan" in response.json()

def test_explain_invalid():
    response = client.get("/api/analytics/explain/invalid_query")
    assert response.status_code == 200
    assert "error" in response.json()
