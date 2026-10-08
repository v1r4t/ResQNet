# backend/tests/test_incidents.py
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_submit_incident_report():
    response = client.post("/api/incidents/report", json={"raw_text": "Major accident on A1-A2. Two lanes blocked."})
    assert response.status_code == 200
    data = response.json()
    assert "report_id" in data
    assert "extracted_data" in data
    assert data["extracted_data"]["type"] == "accident"

def test_create_manual_incident():
    response = client.post("/api/incidents/manual", json={
        "type": "fire",
        "severity": "high",
        "road": "B3",
        "lanes_blocked": 1,
        "description": "Building fire"
    })
    assert response.status_code == 200
    assert "incident_id" in response.json()

def test_list_incidents():
    response = client.get("/api/incidents")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
