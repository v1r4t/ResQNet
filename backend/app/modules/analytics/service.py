# backend/app/modules/analytics/service.py
import psycopg
from app.database import get_connection, release_connection

def get_congestion_hotspots() -> list[dict]:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM v_congestion_hotspots")
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)

def get_incident_frequency() -> list[dict]:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM v_incident_frequency ORDER BY incident_count DESC")
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)

def get_route_performance() -> list[dict]:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM v_route_performance")
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)

def get_response_times() -> list[dict]:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DATE_TRUNC('hour', rr.requested_at) AS hour,
                       AVG(r.total_time_min) AS avg_estimated_time,
                       COUNT(*) AS request_count
                FROM route_request rr
                JOIN route r ON rr.id = r.request_id
                GROUP BY DATE_TRUNC('hour', rr.requested_at)
                ORDER BY hour
            """)
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)

EXPLAIN_WHITELIST = {
    "nearest_vehicle": """
        SELECT ev.id, ev.name, ev.vehicle_type,
               ST_Distance(ev.location, i.location) AS distance_m
        FROM emergency_vehicle ev
        CROSS JOIN intersection i
        WHERE i.id = 1 AND ev.status = 'available'
        ORDER BY ST_Distance(ev.location, i.location)
        LIMIT 1
    """,
    "congestion_hotspots": "SELECT * FROM v_congestion_hotspots",
    "route_reconstruction": "SELECT rs.sequence_order, rs.road_segment_id, r.name, rs.estimated_time_min FROM route_segment rs JOIN road_segment r ON rs.road_segment_id = r.id WHERE rs.route_id = 1 ORDER BY rs.sequence_order",
    "incident_frequency": "SELECT * FROM v_incident_frequency ORDER BY incident_count DESC",
    "road_history": "SELECT * FROM road_status_history WHERE road_segment_id = 1 ORDER BY changed_at DESC",
}

def get_explain_plan(query_id: str) -> dict:
    if query_id not in EXPLAIN_WHITELIST:
        return {"error": "Query not in whitelist"}
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(f"EXPLAIN ANALYZE {EXPLAIN_WHITELIST[query_id]}")
            plan = [row[0] for row in cur.fetchall()]
            return {"query_id": query_id, "plan": plan}
    finally:
        release_connection(conn)
