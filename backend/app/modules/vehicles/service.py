# backend/app/modules/vehicles/service.py
import psycopg
from app.database import get_connection, release_connection

def get_vehicles(vehicle_type: str = None, status: str = None, zone_id: int = None) -> list[dict]:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            query = "SELECT id, vehicle_type, name, status, current_intersection_id FROM emergency_vehicle"
            conditions = []
            params = []
            if vehicle_type:
                conditions.append("vehicle_type = %s")
                params.append(vehicle_type)
            if status:
                conditions.append("status = %s")
                params.append(status)
            if zone_id:
                conditions.append("current_zone_id = %s")
                params.append(zone_id)
            if conditions:
                query += " WHERE " + " AND ".join(conditions)
            cur.execute(query, params)
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)

def get_vehicle_status_summary() -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT status, COUNT(*) as count
                FROM emergency_vehicle
                GROUP BY status
            """)
            return {row[0]: row[1] for row in cur.fetchall()}
    finally:
        release_connection(conn)

def update_vehicle_location(vehicle_id: int, intersection_id: int) -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE emergency_vehicle SET current_intersection_id = %s WHERE id = %s",
                (intersection_id, vehicle_id)
            )
            conn.commit()
            return {"vehicle_id": vehicle_id, "current_intersection_id": intersection_id}
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

def get_nearest_vehicle(intersection_id: int, vehicle_type: str) -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT ev.id, ev.name, ev.vehicle_type,
                       ST_Distance(ev.location, i.location) AS distance_m
                FROM emergency_vehicle ev
                CROSS JOIN intersection i
                WHERE i.id = %s AND ev.vehicle_type = %s AND ev.status = 'available'
                ORDER BY ST_Distance(ev.location, i.location)
                LIMIT 1
            """, (intersection_id, vehicle_type))
            row = cur.fetchone()
            if row:
                return {"id": row[0], "name": row[1], "vehicle_type": row[2], "distance_m": row[3]}
            return None
    finally:
        release_connection(conn)
