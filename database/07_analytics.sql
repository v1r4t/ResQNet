-- database/07_analytics.sql
-- These queries are used for EXPLAIN ANALYZE demonstration

-- Query 1: Nearest vehicle (spatial)
EXPLAIN ANALYZE
SELECT ev.id, ev.name, ev.vehicle_type,
       ST_Distance(ev.location, i.location) AS distance_m
FROM emergency_vehicle ev
CROSS JOIN intersection i
WHERE i.id = 1 AND ev.status = 'available'
ORDER BY ST_Distance(ev.location, i.location)
LIMIT 1;

-- Query 2: Congestion hotspots
EXPLAIN ANALYZE
SELECT * FROM v_congestion_hotspots;

-- Query 3: Route reconstruction
EXPLAIN ANALYZE
SELECT rs.sequence_order, rs.road_segment_id, r.name, rs.estimated_time_min
FROM route_segment rs
JOIN road_segment r ON rs.road_segment_id = r.id
WHERE rs.route_id = 1
ORDER BY rs.sequence_order;

-- Query 4: Incident frequency
EXPLAIN ANALYZE
SELECT * FROM v_incident_frequency ORDER BY incident_count DESC;

-- Query 5: Road history
EXPLAIN ANALYZE
SELECT * FROM road_status_history WHERE road_segment_id = 1 ORDER BY changed_at DESC;
