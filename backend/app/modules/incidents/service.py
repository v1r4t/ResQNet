# backend/app/modules/incidents/service.py
import json
import psycopg
from app.database import get_connection, release_connection
from app.llm import get_extractor
from app.modules.incidents.schemas import IncidentReportInput, ManualIncidentInput

VALID_SEVERITIES = {"low", "medium", "high", "critical"}

def submit_report(raw_text: str) -> dict:
    extractor = get_extractor()
    extracted = extractor.extract(raw_text)

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Insert report with dynamic extraction metadata
            cur.execute(
                "INSERT INTO incident_report (raw_text, extracted_data, extraction_confidence, extraction_source, extraction_fallback) VALUES (%s, %s, %s, %s, %s) RETURNING id",
                (raw_text, json.dumps(extracted.model_dump()), extractor.confidence, extractor.source, False)
            )
            report_id = cur.fetchone()[0]

            # Process incident
            cur.execute("CALL sp_process_incident_report(%s)", (report_id,))

            # Get affected roads
            cur.execute(
                "SELECT road_segment_id FROM incident_road WHERE incident_id = (SELECT incident_id FROM incident_report WHERE id = %s)",
                (report_id,)
            )
            affected_roads = [row[0] for row in cur.fetchall()]

            # Get incident_id
            cur.execute("SELECT incident_id FROM incident_report WHERE id = %s", (report_id,))
            incident_id = cur.fetchone()[0]

            conn.commit()
            return {
                "report_id": report_id,
                "incident_id": incident_id,
                "extracted_data": extracted.model_dump(),
                "extraction_source": extractor.source,
                "extraction_fallback": False,
                "affected_roads": affected_roads
            }
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

def create_manual_incident(data: ManualIncidentInput) -> dict:
    if data.severity not in VALID_SEVERITIES:
        raise ValueError(f"Invalid severity: {data.severity}. Must be one of: {', '.join(VALID_SEVERITIES)}")

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO incident (type, severity, status, description) VALUES (%s, %s, 'active', %s) RETURNING id",
                (data.type, data.severity, data.description)
            )
            incident_id = cur.fetchone()[0]

            # Find matching roads
            cur.execute("SELECT id FROM road_segment WHERE name ILIKE %s", (f"%{data.road}%",))
            roads = cur.fetchall()

            for road in roads:
                cur.execute(
                    "INSERT INTO incident_road (incident_id, road_segment_id, impact_level, lanes_blocked) VALUES (%s, %s, %s, %s)",
                    (incident_id, road[0], "moderate" if data.severity == "medium" else "severe", data.lanes_blocked)
                )

            conn.commit()
            return {"incident_id": incident_id, "affected_roads": [r[0] for r in roads]}
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

def get_incidents(status: str = None, severity: str = None, zone_id: int = None) -> list[dict]:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            query = "SELECT i.id, i.type, i.severity, i.status, i.description, i.started_at, i.cleared_at FROM incident i"
            conditions = []
            params = []
            if status:
                conditions.append("i.status = %s")
                params.append(status)
            if severity:
                conditions.append("i.severity = %s")
                params.append(severity)
            if zone_id:
                conditions.append("i.id IN (SELECT ir.incident_id FROM incident_road ir JOIN road_segment rs ON ir.road_segment_id = rs.id JOIN intersection inter ON rs.from_intersection_id = inter.id WHERE inter.zone_id = %s)")
                params.append(zone_id)
            if conditions:
                query += " WHERE " + " AND ".join(conditions)
            query += " ORDER BY i.started_at DESC"
            cur.execute(query, params)
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)

def get_incident_history() -> list[dict]:
    """Get cleared incidents (incident history)."""
    return get_incidents(status="cleared")

def clear_incident(incident_id: int) -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Verify incident exists
            cur.execute("SELECT id FROM incident WHERE id = %s", (incident_id,))
            if not cur.fetchone():
                raise ValueError(f"Incident {incident_id} not found")

            cur.execute("CALL sp_clear_incident(%s)", (incident_id,))
            conn.commit()
            return {"incident_id": incident_id, "status": "cleared"}
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

def get_nearby_incidents(lat: float, lon: float, radius_m: float = 1000) -> list[dict]:
    """Find active incidents near a location using PostGIS spatial query."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT i.id, i.type, i.severity, i.status, i.description, i.started_at,
                       ST_Distance(rs.geom, ST_SetSRID(ST_MakePoint(%s, %s), 4326)) AS distance_m
                FROM incident i
                JOIN incident_road ir ON i.id = ir.incident_id
                JOIN road_segment rs ON ir.road_segment_id = rs.id
                WHERE i.status = 'active'
                AND ST_DWithin(rs.geom::geography, ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography, %s)
                ORDER BY distance_m
            """, (lon, lat, lon, lat, radius_m))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)
