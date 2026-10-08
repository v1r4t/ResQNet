-- database/tests/test_procedures.sql
-- Test sp_recalculate_road_impact
-- Setup: Create test data
INSERT INTO city (name, bounds) VALUES ('Test City', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326));
INSERT INTO zone (city_id, name, polygon) VALUES (1, 'Test Zone', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326));
INSERT INTO intersection (zone_id, name, location) VALUES (1, 'A', ST_GeomFromText('POINT(0 0)', 4326));
INSERT INTO intersection (zone_id, name, location) VALUES (1, 'B', ST_GeomFromText('POINT(1 1)', 4326));
INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
VALUES (1, 2, 'Test Road', 1000, 60, 2, ST_GeomFromText('LINESTRING(0 0, 1 1)', 4326));
INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level) VALUES (1, 10, 'free');

-- Test: Add incident and verify road impact
INSERT INTO incident (type, severity, status, description) VALUES ('accident', 'high', 'active', 'Test accident');
INSERT INTO incident_road (incident_id, road_segment_id, impact_level, lanes_blocked) VALUES (1, 1, 'severe', 1);

-- Verify travel time increased
SELECT travel_time_min FROM traffic_state WHERE road_segment_id = 1;
-- Expected: > 10 (base time * multiplier)

-- Test: Clear incident and verify recalculation
CALL sp_clear_incident(1);
SELECT travel_time_min FROM traffic_state WHERE road_segment_id = 1;
-- Expected: Back to base time (10)

-- Cleanup
DELETE FROM incident_road WHERE incident_id = 1;
DELETE FROM incident WHERE id = 1;
DELETE FROM traffic_state WHERE road_segment_id = 1;
DELETE FROM road_segment WHERE id = 1;
DELETE FROM intersection WHERE id IN (1, 2);
DELETE FROM zone WHERE id = 1;
DELETE FROM city WHERE id = 1;
