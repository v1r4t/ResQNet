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
            for row in cur.fetchall():
                road_id, from_id, to_id, dist, time_min = row
                if from_id not in graph:
                    graph[from_id] = []
                graph[from_id].append(Edge(to_node=to_id, weight=time_min, road_segment_id=road_id))
            return graph
    finally:
        release_connection(conn)

def calculate_route(origin_id: int, destination_id: int, vehicle_id: int = None) -> dict:
    # Get network snapshot (no transaction held during routing)
    graph = get_network_snapshot()

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

            # Use default vehicle if none provided
            if vehicle_id is None:
                cur.execute("SELECT id FROM emergency_vehicle WHERE status = 'available' LIMIT 1")
                vehicle_row = cur.fetchone()
                vehicle_id = vehicle_row[0] if vehicle_row else 1

            # Create route request
            cur.execute(
                "INSERT INTO route_request (vehicle_id, origin_id, destination_id, priority) VALUES (%s, %s, %s, %s) RETURNING id",
                (vehicle_id, origin_id, destination_id, 5)
            )
            request_id = cur.fetchone()[0]

            # Create route
            cur.execute(
                "INSERT INTO route (request_id, route_type, total_time_min, total_distance_m, status, network_version_id) VALUES (%s, 'fastest', %s, %s, 'active', %s) RETURNING id",
                (request_id, result.total_time, result.total_distance, network_version_id)
            )
            route_id = cur.fetchone()[0]

            # Create route segments
            for seq, road_id in enumerate(result.segments):
                cur.execute(
                    "INSERT INTO route_segment (route_id, road_segment_id, sequence_order, estimated_time_min) VALUES (%s, %s, %s, %s)",
                    (route_id, road_id, seq, 0.0)
                )

            conn.commit()
            return {"route_id": route_id, "request_id": request_id, "total_time_min": result.total_time, "total_distance_m": result.total_distance}
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)

def recalculate_routes() -> dict:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, road_segment_id FROM route_recalculation_queue WHERE status = 'pending'")
            pending = cur.fetchall()
            results = []
            for queue_id, road_id in pending:
                # Find affected routes
                cur.execute("""
                    SELECT r.id, rr.origin_id, rr.destination_id
                    FROM route r
                    JOIN route_request rr ON r.request_id = rr.id
                    WHERE r.status = 'active'
                    AND r.id IN (
                        SELECT rs.route_id FROM route_segment rs WHERE rs.road_segment_id = %s
                    )
                """, (road_id,))
                affected = cur.fetchall()
                for route_id, origin, dest in affected:
                    result = calculate_route(origin, dest)
                    if result:
                        results.append(result)
                cur.execute("UPDATE route_recalculation_queue SET status = 'completed', processed_at = NOW() WHERE id = %s", (queue_id,))
            conn.commit()
            return {"recalculated": len(results), "routes": results}
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        release_connection(conn)
