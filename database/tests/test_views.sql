-- database/tests/test_views.sql
-- Tests for the views in database/05_views.sql
-- Run with: psql -U postgres -d resqnet -v ON_ERROR_STOP=1 -f database/tests/test_views.sql

-- ============================================================
-- Cleanup any leftover data from previous test runs (FK-safe order)
-- ============================================================
DELETE FROM route_recalculation_queue
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%');
DELETE FROM route_segment
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%');
DELETE FROM route
 WHERE request_id IN (
     SELECT rr.id FROM route_request rr
     JOIN emergency_vehicle ev ON rr.vehicle_id = ev.id
     WHERE ev.name LIKE 'ViewTest%');
DELETE FROM route_request
 WHERE vehicle_id IN (SELECT id FROM emergency_vehicle WHERE name LIKE 'ViewTest%');
DELETE FROM road_status_history
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%');
DELETE FROM incident_road
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%')
    OR incident_id IN (SELECT id FROM incident WHERE description LIKE 'ViewTest%');
DELETE FROM incident_report WHERE raw_text LIKE 'ViewTest%';
DELETE FROM incident WHERE description LIKE 'ViewTest%';
DELETE FROM emergency_vehicle WHERE name LIKE 'ViewTest%';
DELETE FROM traffic_state
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%');
DELETE FROM road_segment WHERE name LIKE 'ViewTest%';
DELETE FROM intersection WHERE name LIKE 'VT-%';
DELETE FROM zone WHERE name = 'ViewTest Zone';
DELETE FROM city WHERE name = 'ViewTest City';

-- ============================================================
-- Setup: base test data
-- Every road is 1000 m @ 60 km/h => base travel time = 1.0 min
-- ============================================================
INSERT INTO city (name, bounds)
VALUES ('ViewTest City', ST_GeomFromText('POLYGON((0 0, 0 5, 5 5, 5 0, 0 0))', 4326));

INSERT INTO zone (city_id, name, polygon)
SELECT id, 'ViewTest Zone', ST_GeomFromText('POLYGON((0 0, 0 5, 5 5, 5 0, 0 0))', 4326)
FROM city WHERE name = 'ViewTest City';

INSERT INTO intersection (zone_id, name, location)
SELECT id, 'VT-A', ST_GeomFromText('POINT(0 0)', 4326) FROM zone WHERE name = 'ViewTest Zone';
INSERT INTO intersection (zone_id, name, location)
SELECT id, 'VT-B', ST_GeomFromText('POINT(1 1)', 4326) FROM zone WHERE name = 'ViewTest Zone';
INSERT INTO intersection (zone_id, name, location)
SELECT id, 'VT-C', ST_GeomFromText('POINT(2 2)', 4326) FROM zone WHERE name = 'ViewTest Zone';
INSERT INTO intersection (zone_id, name, location)
SELECT id, 'VT-D', ST_GeomFromText('POINT(3 3)', 4326) FROM zone WHERE name = 'ViewTest Zone';

INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
SELECT a.id, b.id, 'ViewTest Hotspot Road', 1000, 60, 2, ST_GeomFromText('LINESTRING(0 0, 1 1)', 4326)
FROM intersection a, intersection b WHERE a.name = 'VT-A' AND b.name = 'VT-B';

INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
SELECT a.id, b.id, 'ViewTest Normal Road', 1000, 60, 2, ST_GeomFromText('LINESTRING(2 2, 3 3)', 4326)
FROM intersection a, intersection b WHERE a.name = 'VT-C' AND b.name = 'VT-D';

INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
SELECT a.id, b.id, 'ViewTest Incident Road', 1000, 60, 2, ST_GeomFromText('LINESTRING(0 0, 2 2)', 4326)
FROM intersection a, intersection b WHERE a.name = 'VT-A' AND b.name = 'VT-C';

-- Hotspot road runs at 5x base time; the other two run at base time
INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level)
SELECT id, 5.0, 'heavy' FROM road_segment WHERE name = 'ViewTest Hotspot Road';
INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level)
SELECT id, 1.0, 'free' FROM road_segment WHERE name = 'ViewTest Normal Road';
INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level)
SELECT id, 1.0, 'free' FROM road_segment WHERE name = 'ViewTest Incident Road';

-- ============================================================
-- Test 1: v_current_network lists every road with traffic state
-- ============================================================
\echo 'Test 1: v_current_network lists all roads with traffic state'
DO $$
DECLARE
    v_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM v_current_network WHERE road_name LIKE 'ViewTest%';
    ASSERT v_count = 3, format('Test 1 FAILED: expected 3 roads, got %s', v_count);

    SELECT COUNT(*) INTO v_count
    FROM v_current_network
    WHERE road_name LIKE 'ViewTest%' AND active_incidents::jsonb = '[]'::jsonb;
    ASSERT v_count = 3,
        format('Test 1 FAILED: expected 3 roads with no active incidents, got %s', v_count);

    RAISE NOTICE 'Test 1 PASSED: 3 roads listed, no active incidents';
END $$;

-- ============================================================
-- Test 2: v_congestion_hotspots aggregates hotspots per zone
-- Hotspot Road (5x base) qualifies; Normal/Incident roads (1x) do not.
-- ============================================================
\echo 'Test 2: v_congestion_hotspots groups hotspots by zone'
DO $$
DECLARE
    v_rows BIGINT;
    v_zone VARCHAR;
    v_count BIGINT;
    v_avg FLOAT;
    v_ratio FLOAT;
BEGIN
    SELECT COUNT(*) INTO v_rows
    FROM v_congestion_hotspots WHERE zone_name = 'ViewTest Zone';
    ASSERT v_rows = 1, format('Test 2 FAILED: expected 1 zone row, got %s', v_rows);

    SELECT zone_name, hotspot_count, avg_travel_time, avg_congestion_ratio
    INTO v_zone, v_count, v_avg, v_ratio
    FROM v_congestion_hotspots WHERE zone_name = 'ViewTest Zone';

    ASSERT v_count = 1, format('Test 2 FAILED: expected hotspot_count 1, got %s', v_count);
    ASSERT v_avg = 5.0, format('Test 2 FAILED: expected avg_travel_time 5.0, got %s', v_avg);
    ASSERT v_ratio = 5.0, format('Test 2 FAILED: expected avg_congestion_ratio 5.0, got %s', v_ratio);

    RAISE NOTICE 'Test 2 PASSED: zone=%, hotspots=%, avg=%, ratio=%', v_zone, v_count, v_avg, v_ratio;
END $$;

-- ============================================================
-- Test 3: v_current_network reports active incidents only
-- Insert one active and one cleared incident on the same road.
-- ============================================================
\echo 'Test 3: v_current_network reports active incidents only'
INSERT INTO incident (type, severity, status, description)
VALUES ('accident', 'high', 'active', 'ViewTest active incident');
INSERT INTO incident_road (incident_id, road_segment_id, impact_level, lanes_blocked)
SELECT i.id, rs.id, 'severe', 1
FROM incident i, road_segment rs
WHERE i.description = 'ViewTest active incident' AND rs.name = 'ViewTest Incident Road';

INSERT INTO incident (type, severity, status, description)
VALUES ('flood', 'low', 'cleared', 'ViewTest cleared incident');
INSERT INTO incident_road (incident_id, road_segment_id, impact_level, lanes_blocked)
SELECT i.id, rs.id, 'minor', 0
FROM incident i, road_segment rs
WHERE i.description = 'ViewTest cleared incident' AND rs.name = 'ViewTest Incident Road';

DO $$
DECLARE
    v_json JSON;
BEGIN
    SELECT active_incidents INTO v_json
    FROM v_current_network WHERE road_name = 'ViewTest Incident Road';

    ASSERT json_array_length(v_json) = 1,
        format('Test 3 FAILED: expected 1 active incident, got %s', json_array_length(v_json));
    ASSERT v_json->0->>'type' = 'accident',
        format('Test 3 FAILED: expected type accident, got %s', v_json->0->>'type');
    ASSERT v_json->0->>'severity' = 'high',
        format('Test 3 FAILED: expected severity high, got %s', v_json->0->>'severity');
    ASSERT v_json->0->>'impact_level' = 'severe',
        format('Test 3 FAILED: expected impact_level severe, got %s', v_json->0->>'impact_level');

    RAISE NOTICE 'Test 3 PASSED: cleared incident excluded, active incident reported';
END $$;

-- ============================================================
-- Test 4: v_incident_frequency counts incidents per road/type/day
-- ============================================================
\echo 'Test 4: v_incident_frequency counts incidents per road/type/day'
DO $$
DECLARE
    v_rows BIGINT;
    v_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_rows
    FROM v_incident_frequency WHERE road_name = 'ViewTest Incident Road';
    ASSERT v_rows = 2, format('Test 4 FAILED: expected 2 frequency rows, got %s', v_rows);

    SELECT incident_count INTO v_count
    FROM v_incident_frequency
    WHERE road_name = 'ViewTest Incident Road' AND incident_type = 'accident';
    ASSERT v_count = 1, format('Test 4 FAILED: expected accident count 1, got %s', v_count);

    RAISE NOTICE 'Test 4 PASSED: 2 rows, accident count = %', v_count;
END $$;

-- ============================================================
-- Test 5: v_route_performance includes completed routes only
-- Two routes have actual_time_min set: one completed, one active.
-- Only the completed route should appear.
-- ============================================================
\echo 'Test 5: v_route_performance includes completed routes only'
INSERT INTO emergency_vehicle (vehicle_type, name, status, current_zone_id, location)
SELECT 'ambulance', 'ViewTest Ambulance', 'available', id, ST_GeomFromText('POINT(0 0)', 4326)
FROM zone WHERE name = 'ViewTest Zone';

INSERT INTO route_request (vehicle_id, origin_id, destination_id, priority)
SELECT ev.id, a.id, b.id, 1
FROM emergency_vehicle ev, intersection a, intersection b
WHERE ev.name = 'ViewTest Ambulance' AND a.name = 'VT-A' AND b.name = 'VT-B';

INSERT INTO route (request_id, route_type, total_time_min, total_distance_m, actual_time_min, status)
SELECT rr.id, 'fastest', 10.0, 1000.0, 12.0, 'completed'
FROM route_request rr
JOIN emergency_vehicle ev ON rr.vehicle_id = ev.id
WHERE ev.name = 'ViewTest Ambulance';

INSERT INTO route (request_id, route_type, total_time_min, total_distance_m, actual_time_min, status)
SELECT rr.id, 'shortest', 8.0, 900.0, 9.0, 'active'
FROM route_request rr
JOIN emergency_vehicle ev ON rr.vehicle_id = ev.id
WHERE ev.name = 'ViewTest Ambulance';

DO $$
DECLARE
    v_all BIGINT;
    v_rows BIGINT;
    v_status VARCHAR;
    v_est FLOAT;
    v_actual FLOAT;
    v_delta FLOAT;
    v_vtype VARCHAR;
BEGIN
    -- Sanity check: both routes actually have an actual_time_min
    SELECT COUNT(*) INTO v_all
    FROM route r
    JOIN route_request rr ON r.request_id = rr.id
    JOIN emergency_vehicle ev ON rr.vehicle_id = ev.id
    WHERE ev.name = 'ViewTest Ambulance' AND r.actual_time_min IS NOT NULL;
    ASSERT v_all = 2,
        format('Test 5 SETUP FAILED: expected 2 routes with actual_time, got %s', v_all);

    SELECT COUNT(*) INTO v_rows
    FROM v_route_performance
    WHERE route_id IN (
        SELECT r.id FROM route r
        JOIN route_request rr ON r.request_id = rr.id
        JOIN emergency_vehicle ev ON rr.vehicle_id = ev.id
        WHERE ev.name = 'ViewTest Ambulance');
    ASSERT v_rows = 1,
        format('Test 5 FAILED: expected 1 completed route, got %s', v_rows);

    SELECT status, estimated_time, actual_time_min, performance_delta, vehicle_type
    INTO v_status, v_est, v_actual, v_delta, v_vtype
    FROM v_route_performance
    WHERE route_id IN (
        SELECT r.id FROM route r
        JOIN route_request rr ON r.request_id = rr.id
        JOIN emergency_vehicle ev ON rr.vehicle_id = ev.id
        WHERE ev.name = 'ViewTest Ambulance');

    ASSERT v_status = 'completed', format('Test 5 FAILED: expected status completed, got %s', v_status);
    ASSERT v_est = 10.0, format('Test 5 FAILED: expected estimated_time 10.0, got %s', v_est);
    ASSERT v_actual = 12.0, format('Test 5 FAILED: expected actual_time_min 12.0, got %s', v_actual);
    ASSERT v_delta = 2.0, format('Test 5 FAILED: expected performance_delta 2.0, got %s', v_delta);
    ASSERT v_vtype = 'ambulance', format('Test 5 FAILED: expected vehicle_type ambulance, got %s', v_vtype);

    RAISE NOTICE 'Test 5 PASSED: only completed route returned (delta=%, vehicle=%)', v_delta, v_vtype;
END $$;

-- ============================================================
-- Cleanup: remove all test data (FK-safe order)
-- ============================================================
DELETE FROM route_recalculation_queue
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%');
DELETE FROM route_segment
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%');
DELETE FROM route
 WHERE request_id IN (
     SELECT rr.id FROM route_request rr
     JOIN emergency_vehicle ev ON rr.vehicle_id = ev.id
     WHERE ev.name LIKE 'ViewTest%');
DELETE FROM route_request
 WHERE vehicle_id IN (SELECT id FROM emergency_vehicle WHERE name LIKE 'ViewTest%');
DELETE FROM road_status_history
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%');
DELETE FROM incident_road
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%')
    OR incident_id IN (SELECT id FROM incident WHERE description LIKE 'ViewTest%');
DELETE FROM incident_report WHERE raw_text LIKE 'ViewTest%';
DELETE FROM incident WHERE description LIKE 'ViewTest%';
DELETE FROM emergency_vehicle WHERE name LIKE 'ViewTest%';
DELETE FROM traffic_state
 WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name LIKE 'ViewTest%');
DELETE FROM road_segment WHERE name LIKE 'ViewTest%';
DELETE FROM intersection WHERE name LIKE 'VT-%';
DELETE FROM zone WHERE name = 'ViewTest Zone';
DELETE FROM city WHERE name = 'ViewTest City';

\echo 'All view tests passed.'
