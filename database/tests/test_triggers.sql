-- database/tests/test_triggers.sql
-- Test 1: trg_traffic_state_history
INSERT INTO city (name, bounds) VALUES ('Test City', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326));
INSERT INTO zone (city_id, name, polygon) VALUES (1, 'Test Zone', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326));
INSERT INTO intersection (zone_id, name, location) VALUES (1, 'A', ST_GeomFromText('POINT(0 0)', 4326));
INSERT INTO intersection (zone_id, name, location) VALUES (1, 'B', ST_GeomFromText('POINT(1 1)', 4326));
INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
VALUES (1, 2, 'Test Road', 1000, 60, 2, ST_GeomFromText('LINESTRING(0 0, 1 1)', 4326));
INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level) VALUES (1, 10, 'free');

-- Update travel time
UPDATE traffic_state SET travel_time_min = 15 WHERE road_segment_id = 1;

-- Verify history was logged
SELECT COUNT(*) FROM road_status_history WHERE road_segment_id = 1;
-- Expected: 1
