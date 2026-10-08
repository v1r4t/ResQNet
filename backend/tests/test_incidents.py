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
    assert data["extraction_source"] == "mock"
    assert data["extraction_fallback"] is False

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

def test_create_manual_incident_invalid_severity():
    response = client.post("/api/incidents/manual", json={
        "type": "fire",
        "severity": "invalid",
        "road": "B3",
        "lanes_blocked": 1,
        "description": "Building fire"
    })
    assert response.status_code == 422

def test_list_incidents():
    response = client.get("/api/incidents")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_list_incidents_filter_by_status():
    response = client.get("/api/incidents?status=active")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    for incident in data:
        assert incident["status"] == "active"

def test_list_incidents_filter_by_severity():
    response = client.get("/api/incidents?severity=high")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    for incident in data:
        assert incident["severity"] == "high"

def test_clear_incident():
    # First create an incident
    create_response = client.post("/api/incidents/manual", json={
        "type": "fire",
        "severity": "high",
        "road": "B3",
        "lanes_blocked": 1,
        "description": "Test fire"
    })
    assert create_response.status_code == 200
    incident_id = create_response.json()["incident_id"]

    # Clear the incident
    response = client.post(f"/api/incidents/{incident_id}/clear")
    assert response.status_code == 200
    data = response.json()
    assert data["incident_id"] == incident_id
    assert data["status"] == "cleared"

def test_clear_nonexistent_incident():
    response = client.post("/api/incidents/99999/clear")
    assert response.status_code == 404

def test_incident_history():
    # Create and clear an incident to ensure history has data
    create_response = client.post("/api/incidents/manual", json={
        "type": "accident",
        "severity": "medium",
        "road": "A1",
        "lanes_blocked": 1,
        "description": "Test accident for history"
    })
    assert create_response.status_code == 200
    incident_id = create_response.json()["incident_id"]

    # Clear it
    client.post(f"/api/incidents/{incident_id}/clear")

    # Check history
    response = client.get("/api/incidents/history")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    # All items in history should be cleared
    for incident in data:
        assert incident["status"] == "cleared"

def test_nearby_incidents():
    # Create an incident at a known location first
    create_response = client.post("/api/incidents/manual", json={
        "type": "accident",
        "severity": "high",
        "road": "A1",
        "lanes_blocked": 2,
        "description": "Test nearby incident"
    })
    assert create_response.status_code == 200

    # Query nearby incidents (using coordinates that should match seed data)
    response = client.get("/api/incidents/nearby?lat=12.9716&lon=77.5946&radius_m=5000")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)

def test_nearby_incidents_requires_params():
    # Should fail without required params
    response = client.get("/api/incidents/nearby")
    assert response.status_code == 422
