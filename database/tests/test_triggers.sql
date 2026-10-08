-- database/tests/test_triggers.sql

-- ============================================================
-- Cleanup any leftover data from previous test runs
-- ============================================================
DELETE FROM route_recalculation_queue WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road');
DELETE FROM route_segment WHERE route_id IN (SELECT id FROM route WHERE request_id IN (SELECT id FROM route_request WHERE origin_id IN (SELECT id FROM intersection WHERE name IN ('A', 'B'))));
DELETE FROM route WHERE request_id IN (SELECT id FROM route_request WHERE origin_id IN (SELECT id FROM intersection WHERE name IN ('A', 'B')));
DELETE FROM route_request WHERE origin_id IN (SELECT id FROM intersection WHERE name IN ('A', 'B'));
DELETE FROM incident_road WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road');
DELETE FROM incident WHERE id IN (SELECT incident_id FROM incident_road);
DELETE FROM emergency_vehicle WHERE name = 'Test Ambulance';
DELETE FROM road_status_history WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road');
DELETE FROM traffic_state WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road');
DELETE FROM road_segment WHERE name = 'Test Road';
DELETE FROM intersection WHERE name IN ('A', 'B');
DELETE FROM zone WHERE name = 'Test Zone';
DELETE FROM city WHERE name = 'Test City';

-- Reset sequences so IDs start at 1
SELECT setval('city_id_seq', 1, false);
SELECT setval('zone_id_seq', 1, false);
SELECT setval('intersection_id_seq', 1, false);
SELECT setval('road_segment_id_seq', 1, false);
SELECT setval('emergency_vehicle_id_seq', 1, false);
SELECT setval('route_request_id_seq', 1, false);
SELECT setval('route_id_seq', 1, false);
SELECT setval('route_segment_id_seq', 1, false);
SELECT setval('incident_id_seq', 1, false);

-- ============================================================
-- Setup: Create base test data
-- ============================================================
INSERT INTO city (name, bounds) VALUES ('Test City', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326));
INSERT INTO zone (city_id, name, polygon) VALUES (1, 'Test Zone', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326));
INSERT INTO intersection (zone_id, name, location) VALUES (1, 'A', ST_GeomFromText('POINT(0 0)', 4326));
INSERT INTO intersection (zone_id, name, location) VALUES (1, 'B', ST_GeomFromText('POINT(1 1)', 4326));
INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
VALUES (1, 2, 'Test Road', 1000, 60, 2, ST_GeomFromText('LINESTRING(0 0, 1 1)', 4326));
INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level) VALUES (1, 10, 'free');

-- ============================================================
-- Test 1: trg_traffic_state_history
-- ============================================================
UPDATE traffic_state SET travel_time_min = 15 WHERE road_segment_id = 1;

SELECT COUNT(*) AS test1_history_count FROM road_status_history WHERE road_segment_id = 1;
-- Expected: 1

-- ============================================================
-- Test 2: trg_route_invalidation
-- ============================================================
-- Create a vehicle (needed for route_request.vehicle_id NOT NULL)
INSERT INTO emergency_vehicle (vehicle_type, name, status, current_zone_id)
VALUES ('ambulance', 'Test Ambulance', 'available', 1);

-- Create a route that uses road_segment 1
INSERT INTO route_request (vehicle_id, origin_id, destination_id, priority) VALUES (1, 1, 2, 5);
INSERT INTO route (request_id, route_type, total_time_min, total_distance_m, status)
VALUES (1, 'fastest', 10, 1000, 'active');
INSERT INTO route_segment (route_id, road_segment_id, sequence_order, estimated_time_min)
VALUES (1, 1, 1, 10);

-- Update travel time by >20% (10 -> 20 = 100% change)
UPDATE traffic_state SET travel_time_min = 20 WHERE road_segment_id = 1;

-- Verify route was marked stale
SELECT status AS test2_route_status FROM route WHERE id = 1;
-- Expected: stale

-- Verify recalculation queue entry was created
SELECT COUNT(*) AS test2_queue_count FROM route_recalculation_queue WHERE road_segment_id = 1 AND status = 'pending';
-- Expected: 1

-- ============================================================
-- Test 3: trg_incident_road_update
-- ============================================================
INSERT INTO incident (type, severity, status) VALUES ('accident', 'high', 'active');
INSERT INTO incident_road (incident_id, road_segment_id, impact_level, lanes_blocked)
VALUES (1, 1, 'severe', 1);

-- If we got here, the trigger executed without error
SELECT 'trigger 3 executed successfully' AS test3_result;

-- ============================================================
-- Test 4: trg_vehicle_location_sync
-- ============================================================
-- Update vehicle to a different intersection (B at POINT(1 1))
UPDATE emergency_vehicle SET current_intersection_id = 2 WHERE id = 1;

-- Verify location was synced to intersection B's location
SELECT ST_AsText(location) AS test4_location FROM emergency_vehicle WHERE id = 1;
-- Expected: POINT(1 1)

-- ============================================================
-- Cleanup: Remove all test data (respect FK constraints)
-- ============================================================
DELETE FROM route_recalculation_queue WHERE road_segment_id = 1;
DELETE FROM route_segment WHERE route_id = 1;
DELETE FROM route WHERE id = 1;
DELETE FROM route_request WHERE id = 1;
DELETE FROM incident_road WHERE incident_id = 1;
DELETE FROM incident WHERE id = 1;
DELETE FROM emergency_vehicle WHERE id = 1;
DELETE FROM road_status_history WHERE road_segment_id = 1;
DELETE FROM traffic_state WHERE road_segment_id = 1;
DELETE FROM road_segment WHERE id = 1;
DELETE FROM intersection WHERE id IN (1, 2);
DELETE FROM zone WHERE id = 1;
DELETE FROM city WHERE id = 1;
