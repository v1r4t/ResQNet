# backend/app/modules/network/service.py
import psycopg
from app.database import get_connection, release_connection

def get_network_state() -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT v.*, ST_AsGeoJSON(rs.geom)::json AS geometry
                FROM v_current_network v
                JOIN road_segment rs ON rs.id = v.road_segment_id
            """)
            columns = [desc[0] for desc in cur.description]
            roads = [dict(zip(columns, row)) for row in cur.fetchall()]

            cur.execute("SELECT id, name, ST_X(location) AS lon, ST_Y(location) AS lat, location FROM intersection")
            intersections = [{"id": r[0], "name": r[1], "lon": r[2], "lat": r[3], "location": str(r[4])} for r in cur.fetchall()]

            cur.execute("""
                SELECT r.id, r.request_id, r.route_type, r.total_time_min,
                       r.total_distance_m, r.status, r.network_version_id,
                       rr.origin_id, rr.destination_id,
                       rs.sequence_order, rs.road_segment_id
                FROM route r
                JOIN route_request rr ON rr.id = r.request_id
                LEFT JOIN route_segment rs ON rs.route_id = r.id
                WHERE r.status = 'active'
                ORDER BY r.id, rs.sequence_order
            """)
            routes_by_id = {}
            for row in cur.fetchall():
                route_id = row[0]
                route = routes_by_id.setdefault(route_id, {
                    "id": route_id,
                    "request_id": row[1],
                    "route_type": row[2],
                    "total_time_min": row[3],
                    "total_distance_m": row[4],
                    "status": row[5],
                    "network_version_id": row[6],
                    "origin_id": row[7],
                    "destination_id": row[8],
                    "segments": [],
                })
                if row[10] is not None:
                    route["segments"].append({
                        "sequence_order": row[9],
                        "road_segment_id": row[10],
                    })

            return {
                "roads": roads,
                "intersections": intersections,
                "routes": list(routes_by_id.values()),
            }
    finally:
        release_connection(conn)

def get_network_version() -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, created_at, is_active FROM network_version WHERE is_active = TRUE ORDER BY id DESC LIMIT 1")
            row = cur.fetchone()
            if row:
                return {"id": row[0], "created_at": row[1], "is_active": row[2]}
            return None
    finally:
        release_connection(conn)

def get_road_history(road_id: int) -> list[dict]:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM road_status_history WHERE road_segment_id = %s ORDER BY changed_at DESC", (road_id,))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)
