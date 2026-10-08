# backend/app/modules/network/service.py
import psycopg
from app.database import get_connection, release_connection

def get_network_state() -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM v_current_network")
            columns = [desc[0] for desc in cur.description]
            roads = [dict(zip(columns, row)) for row in cur.fetchall()]

            cur.execute("SELECT id, name, location FROM intersection")
            intersections = [{"id": r[0], "name": r[1], "location": r[2]} for r in cur.fetchall()]

            return {"roads": roads, "intersections": intersections}
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
