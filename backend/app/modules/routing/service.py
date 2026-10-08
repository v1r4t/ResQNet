# backend/app/modules/routing/service.py
import json
import psycopg
from app.database import get_connection, release_connection
from app.modules.routing.dijkstra import dijkstra, Edge

def get_network_snapshot() -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT rs.id, rs.from_intersection_id, rs.to_intersection_id,
                       rs.distance_m, ts.travel_time_min
                FROM road_segment rs
                JOIN traffic_state ts ON rs.id = ts.road_segment_id
            """)
            graph = {}
            segment_times = {}
            for row in cur.fetchall():
                road_id, from_id, to_id, dist, time_min = row
                if from_id not in graph:
                    graph[from_id] = []
                graph[from_id].append(Edge(to_node=to_id, weight=time_min, road_segment_id=road_id, distance_m=dist))
                segment_times[road_id] = time_min
            return graph, segment_times
    finally:
        release_connection(conn)

def calculate_route(origin_id: int, destination_id: int, vehicle_id: int = None, priority: int = 5, status: str = 'active') -> dict:
    # Get network snapshot (no transaction held during routing)
    graph, segment_times = get_network_snapshot()

    # Run Dijkstra
    result = dijkstra(graph, origin_id, destination_id)
    if result is None:
        return None

    # Store route in DB
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Get or create network version
            cur.execute("SELECT id FROM network_version WHERE is_active = TRUE ORDER BY id DESC LIMIT 1")
            version_row = cur.fetchone()
            network_version_id = version_row[0] if version_row else None

            # Use nearest available vehicle if none provided
            if vehicle_id is None:
                cur.execute("SELECT id FROM sp_find_nearest_vehicle(%s, 'ambulance') LIMIT 1", (origin_id,))
                vehicle_row = cur.fetchone()
                vehicle_id = vehicle_row[0] if vehicle_row else 1

            # Create route request
            cur.execute(
                "INSERT INTO route_request (vehicle_id, origin_id, destination_id, priority) VALUES (%s, %s, %s, %s) RETURNING id",
                (vehicle_id, origin_id, destination_id, priority)
            )
            request_id = cur.fetchone()[0]

            # Create route
            cur.execute(
                "INSERT INTO route (request_id, route_type, total_time_min, total_distance_m, status, network_version_id) VALUES (%s, 'fastest', %s, %s, %s, %s) RETURNING id",
                (request_id, result.total_time, result.total_distance, status, network_version_id)
            )
            route_id = cur.fetchone()[0]

            # Create route segments with estimated times
            for seq, road_id in enumerate(result.segments):
                est_time = segment_times.get(road_id, 0.0)
                cur.execute(
                    "INSERT INTO route_segment (route_id, road_segment_id, sequence_order, estimated_time_min) VALUES (%s, %s, %s, %s)",
                    (route_id, road_id, seq, est_time)
                )

            conn.commit()
            return {"route_id": route_id, "request_id": request_id, "total_time_min": result.total_time, "total_distance_m": result.total_distance}
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

def recalculate_routes() -> dict:
    # Phase 1: Read queue entries and capture all affected route IDs once (dedupe)
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, road_segment_id FROM route_recalculation_queue WHERE status = 'pending'")
            pending = cur.fetchall()

            # Dedupe queue entries by road_segment_id to avoid redundant processing
            unique_road_ids = set()
            for queue_id, road_id in pending:
                unique_road_ids.add(road_id)

            # Capture all affected route IDs once (dedupe across queue entries)
            # Only look for 'active' routes to avoid exponential growth
            affected_route_ids = set()
            for road_id in unique_road_ids:
                cur.execute("""
                    SELECT r.id FROM route r
                    JOIN route_segment rs ON r.id = rs.route_id
                    WHERE rs.road_segment_id = %s AND r.status = 'active'
                """, (road_id,))
                for row in cur.fetchall():
                    affected_route_ids.add(row[0])

            # Mark old routes as cancelled
            if affected_route_ids:
                cur.execute(
                    "UPDATE route SET status = 'cancelled' WHERE id = ANY(%s)",
                    (list(affected_route_ids),)
                )

            conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

    # Phase 2: Process each affected route (outside transaction)
    results = []
    for route_id in affected_route_ids:
        # Get the route's origin and destination
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT rr.origin_id, rr.destination_id FROM route r
                    JOIN route_request rr ON r.request_id = rr.id
                    WHERE r.id = %s
                """, (route_id,))
                row = cur.fetchone()
                if row:
                    origin, dest = row
        finally:
            release_connection(conn)

        # Calculate new route with 'recalculated' status to prevent exponential growth
        result = calculate_route(origin, dest, status='recalculated')
        if result:
            results.append(result)

    # Phase 3: Mark queue entries as completed
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            for queue_id, road_id in pending:
                cur.execute("UPDATE route_recalculation_queue SET status = 'completed', processed_at = NOW() WHERE id = %s", (queue_id,))
            conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

    return {"recalculated": len(results), "routes": results}

def get_route(route_id: int) -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT r.id, r.request_id, r.route_type, r.total_time_min, r.total_distance_m,
                       r.status, r.network_version_id, r.created_at
                FROM route r WHERE r.id = %s
            """, (route_id,))
            row = cur.fetchone()
            if not row:
                return None
            columns = [desc[0] for desc in cur.description]
            route = dict(zip(columns, row))

            cur.execute("""
                SELECT rs.sequence_order, rs.road_segment_id, rs.estimated_time_min,
                       rseg.name as road_name
                FROM route_segment rs
                JOIN road_segment rseg ON rs.road_segment_id = rseg.id
                WHERE rs.route_id = %s
                ORDER BY rs.sequence_order
            """, (route_id,))
            segments = []
            for seg_row in cur.fetchall():
                segments.append({
                    "sequence_order": seg_row[0],
                    "road_segment_id": seg_row[1],
                    "road_name": seg_row[3],
                    "estimated_time_min": seg_row[2]
                })
            route["segments"] = segments
            return route
    finally:
        release_connection(conn)

def get_request_routes(request_id: int) -> list:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT r.id, r.request_id, r.route_type, r.total_time_min, r.total_distance_m,
                       r.status, r.network_version_id, r.created_at
                FROM route r WHERE r.request_id = %s
                ORDER BY r.created_at DESC
            """, (request_id,))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)

def complete_route(route_id: int, actual_time_min: float) -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE route
                SET status = 'completed', actual_time_min = %s, completed_at = NOW()
                WHERE id = %s
                RETURNING id, status
            """, (actual_time_min, route_id))
            row = cur.fetchone()
            if not row:
                return None
            conn.commit()
            return {"route_id": row[0], "status": row[1]}
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

def get_affected_routes(road_id: int) -> list:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT r.id, r.request_id, r.route_type, r.total_time_min,
                       r.total_distance_m, r.status, r.created_at
                FROM route r
                JOIN route_segment rs ON r.id = rs.route_id
                WHERE rs.road_segment_id = %s
                ORDER BY r.created_at DESC
            """, (road_id,))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        release_connection(conn)
