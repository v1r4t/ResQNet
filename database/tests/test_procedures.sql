-- database/tests/test_procedures.sql
-- Tests for the routines in database/04_procedures.sql
-- Run with: psql -U postgres -d resqnet -v ON_ERROR_STOP=1 -f database/tests/test_procedures.sql

-- ============================================================
-- Cleanup any leftover data from previous test runs (FK-safe order)
-- ============================================================
DELETE FROM route_recalculation_queue WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road');
DELETE FROM route_segment WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road');
DELETE FROM road_status_history WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road');
DELETE FROM incident_road WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road')
    OR incident_id IN (SELECT id FROM incident WHERE description LIKE 'Test incident%');
DELETE FROM incident_report WHERE raw_text = 'Test report raw text';
DELETE FROM incident WHERE description LIKE 'Test incident%';
DELETE FROM emergency_vehicle WHERE name LIKE 'Test Ambulance%';
DELETE FROM traffic_state WHERE road_segment_id IN (SELECT id FROM road_segment WHERE name = 'Test Road');
DELETE FROM road_segment WHERE name = 'Test Road';
DELETE FROM intersection WHERE name IN ('A', 'B');
DELETE FROM zone WHERE name = 'Test Zone';
DELETE FROM city WHERE name = 'Test City';

-- Reset sequences so test data starts at ID 1
SELECT setval('city_id_seq', 1, false);
SELECT setval('zone_id_seq', 1, false);
SELECT setval('intersection_id_seq', 1, false);
SELECT setval('road_segment_id_seq', 1, false);
SELECT setval('incident_id_seq', 1, false);
SELECT setval('incident_report_id_seq', 1, false);
SELECT setval('emergency_vehicle_id_seq', 1, false);

-- ============================================================
-- Setup: Create base test data
-- Road: 1000 m @ 60 km/h => base travel time = 1.0 min, 2 lanes
-- ============================================================
INSERT INTO city (name, bounds) VALUES ('Test City', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326));
INSERT INTO zone (city_id, name, polygon) VALUES (1, 'Test Zone', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326));
INSERT INTO intersection (zone_id, name, location) VALUES (1, 'A', ST_GeomFromText('POINT(0 0)', 4326));
INSERT INTO intersection (zone_id, name, location) VALUES (1, 'B', ST_GeomFromText('POINT(1 1)', 4326));
INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
VALUES (1, 2, 'Test Road', 1000, 60, 2, ST_GeomFromText('LINESTRING(0 0, 1 1)', 4326));
INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level) VALUES (1, 10, 'free');

-- ============================================================
-- Test 1: trg_incident_road_update -> sp_recalculate_road_impact
-- severe impact, 1 of 2 lanes blocked => multiplier 2.0 => 2.0 min
-- ============================================================
\echo 'Test 1: trigger-driven recalculation'
INSERT INTO incident (type, severity, status, description) VALUES ('accident', 'high', 'active', 'Test incident one');
INSERT INTO incident_road (incident_id, road_segment_id, impact_level, lanes_blocked) VALUES (1, 1, 'severe', 1);

DO $$
DECLARE
    v_time FLOAT;
    v_level VARCHAR;
BEGIN
    SELECT travel_time_min, congestion_level INTO v_time, v_level
    FROM traffic_state WHERE road_segment_id = 1;
    ASSERT v_time = 2.0, format('Test 1 FAILED: expected travel_time 2.0, got %s', v_time);
    ASSERT v_level = 'moderate', format('Test 1 FAILED: expected congestion moderate, got %s', v_level);
    RAISE NOTICE 'Test 1 PASSED: travel_time=% min, congestion=%', v_time, v_level;
END $$;

-- ============================================================
-- Test 2: direct CALL sp_recalculate_road_impact (idempotent)
-- ============================================================
\echo 'Test 2: direct CALL sp_recalculate_road_impact'
CALL sp_recalculate_road_impact(1);

DO $$
DECLARE
    v_time FLOAT;
BEGIN
    SELECT travel_time_min INTO v_time FROM traffic_state WHERE road_segment_id = 1;
    ASSERT v_time = 2.0, format('Test 2 FAILED: expected travel_time 2.0, got %s', v_time);
    RAISE NOTICE 'Test 2 PASSED: direct call is idempotent (travel_time=%)', v_time;
END $$;

-- ============================================================
-- Test 3: multi-incident aggregation + full-lane closure
-- severe (x2.0) + moderate (x1.5) and 2 of 2 lanes blocked (x10)
-- => multiplier 30.0 => 30.0 min, congestion blocked
-- ============================================================
\echo 'Test 3: multi-incident aggregation'
INSERT INTO incident (type, severity, status, description) VALUES ('flood', 'medium', 'active', 'Test incident two');
INSERT INTO incident_road (incident_id, road_segment_id, impact_level, lanes_blocked) VALUES (2, 1, 'moderate', 2);

DO $$
DECLARE
    v_time FLOAT;
    v_level VARCHAR;
BEGIN
    SELECT travel_time_min, congestion_level INTO v_time, v_level
    FROM traffic_state WHERE road_segment_id = 1;
    ASSERT v_time = 30.0, format('Test 3 FAILED: expected travel_time 30.0, got %s', v_time);
    ASSERT v_level = 'blocked', format('Test 3 FAILED: expected congestion blocked, got %s', v_level);
    RAISE NOTICE 'Test 3 PASSED: travel_time=% min, congestion=%', v_time, v_level;
END $$;

-- ============================================================
-- Test 4: sp_clear_incident recalculates from remaining incidents
-- Clear incident 2 => only severe remains => 2.0 min
-- ============================================================
\echo 'Test 4: sp_clear_incident with remaining active incident'
CALL sp_clear_incident(2);

DO $$
DECLARE
    v_time FLOAT;
    v_status VARCHAR;
    v_cleared TIMESTAMP;
BEGIN
    SELECT travel_time_min INTO v_time FROM traffic_state WHERE road_segment_id = 1;
    SELECT status, cleared_at INTO v_status, v_cleared FROM incident WHERE id = 2;
    ASSERT v_time = 2.0, format('Test 4 FAILED: expected travel_time 2.0, got %s', v_time);
    ASSERT v_status = 'cleared', format('Test 4 FAILED: expected status cleared, got %s', v_status);
    ASSERT v_cleared IS NOT NULL, 'Test 4 FAILED: cleared_at was not set';
    RAISE NOTICE 'Test 4 PASSED: remaining incident recalculated to % min', v_time;
END $$;

-- ============================================================
-- Test 5: clearing the last incident resets to base time
-- => 1.0 min, congestion free
-- ============================================================
\echo 'Test 5: clearing last incident resets to base'
CALL sp_clear_incident(1);

DO $$
DECLARE
    v_time FLOAT;
    v_level VARCHAR;
BEGIN
    SELECT travel_time_min, congestion_level INTO v_time, v_level
    FROM traffic_state WHERE road_segment_id = 1;
    ASSERT v_time = 1.0, format('Test 5 FAILED: expected travel_time 1.0, got %s', v_time);
    ASSERT v_level = 'free', format('Test 5 FAILED: expected congestion free, got %s', v_level);
    RAISE NOTICE 'Test 5 PASSED: reset to base (% min, %)', v_time, v_level;
END $$;

-- ============================================================
-- Test 6: sp_process_incident_report
-- critical severity -> total impact (x5.0), 1 of 2 lanes blocked
-- => 5.0 min, congestion heavy
-- ============================================================
\echo 'Test 6: sp_process_incident_report'
INSERT INTO incident_report (raw_text, extracted_data)
VALUES ('Test report raw text',
        '{"type":"accident","severity":"critical","road":"Test Road","lanes_blocked":1,"description":"Test incident report"}'::JSONB);

CALL sp_process_incident_report(1);

DO $$
DECLARE
    v_incident_id INTEGER;
    v_type VARCHAR;
    v_severity VARCHAR;
    v_status VARCHAR;
    v_report_incident INTEGER;
    v_impact VARCHAR;
    v_lanes INTEGER;
    v_time FLOAT;
    v_level VARCHAR;
BEGIN
    SELECT id, type, severity, status INTO v_incident_id, v_type, v_severity, v_status
    FROM incident WHERE description = 'Test incident report';
    ASSERT v_incident_id IS NOT NULL, 'Test 6 FAILED: incident was not created';
    ASSERT v_type = 'accident', format('Test 6 FAILED: expected type accident, got %s', v_type);
    ASSERT v_severity = 'critical', format('Test 6 FAILED: expected severity critical, got %s', v_severity);
    ASSERT v_status = 'active', format('Test 6 FAILED: expected status active, got %s', v_status);

    SELECT incident_id INTO v_report_incident FROM incident_report WHERE id = 1;
    ASSERT v_report_incident = v_incident_id, 'Test 6 FAILED: report.incident_id not linked';

    SELECT impact_level, lanes_blocked INTO v_impact, v_lanes
    FROM incident_road WHERE incident_id = v_incident_id AND road_segment_id = 1;
    ASSERT v_impact = 'total', format('Test 6 FAILED: expected impact total, got %s', v_impact);
    ASSERT v_lanes = 1, format('Test 6 FAILED: expected lanes_blocked 1, got %s', v_lanes);

    SELECT travel_time_min, congestion_level INTO v_time, v_level
    FROM traffic_state WHERE road_segment_id = 1;
    ASSERT v_time = 5.0, format('Test 6 FAILED: expected travel_time 5.0, got %s', v_time);
    ASSERT v_level = 'heavy', format('Test 6 FAILED: expected congestion heavy, got %s', v_level);
    RAISE NOTICE 'Test 6 PASSED: incident % created, road linked, travel_time=% min', v_incident_id, v_time;
END $$;

-- Test 6b: missing report raises an exception
DO $$
DECLARE
    v_raised BOOLEAN := FALSE;
BEGIN
    BEGIN
        CALL sp_process_incident_report(99999);
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
        RAISE NOTICE 'Test 6b PASSED: exception raised -> %', SQLERRM;
    END;
    IF NOT v_raised THEN
        RAISE EXCEPTION 'Test 6b FAILED: expected exception for missing report';
    END IF;
END $$;

-- ============================================================
-- Test 7: sp_get_analytics_congestion (returns a result set)
-- ============================================================
\echo 'Test 7: sp_get_analytics_congestion'
DO $$
DECLARE
    v_zone VARCHAR;
    v_avg FLOAT;
    v_count BIGINT;
BEGIN
    SELECT zone_name, avg_travel_time, road_count INTO v_zone, v_avg, v_count
    FROM sp_get_analytics_congestion(24);
    ASSERT v_zone = 'Test Zone', format('Test 7 FAILED: expected zone Test Zone, got %s', v_zone);
    ASSERT v_avg = 5.0, format('Test 7 FAILED: expected avg 5.0, got %s', v_avg);
    ASSERT v_count = 1, format('Test 7 FAILED: expected road_count 1, got %s', v_count);
    RAISE NOTICE 'Test 7 PASSED: zone=%, avg=%, roads=%', v_zone, v_avg, v_count;
END $$;

-- ============================================================
-- Test 8: sp_find_nearest_vehicle (returns a result set)
-- ============================================================
\echo 'Test 8: sp_find_nearest_vehicle'
INSERT INTO emergency_vehicle (vehicle_type, name, status, current_zone_id, location)
VALUES ('ambulance', 'Test Ambulance', 'available', 1, ST_GeomFromText('POINT(0.1 0.1)', 4326)),
       ('ambulance', 'Test Ambulance 2', 'available', 1, ST_GeomFromText('POINT(0.8 0.8)', 4326));

DO $$
DECLARE
    v_name VARCHAR;
    v_dist FLOAT;
BEGIN
    SELECT name, distance_m INTO v_name, v_dist FROM sp_find_nearest_vehicle(1, 'ambulance');
    ASSERT v_name = 'Test Ambulance', format('Test 8 FAILED: expected Test Ambulance, got %s', v_name);
    ASSERT v_dist IS NOT NULL, 'Test 8 FAILED: distance was NULL';
    RAISE NOTICE 'Test 8 PASSED: nearest=% (distance=%)', v_name, v_dist;
END $$;

-- Test 8b: status filter excludes en_route vehicles
UPDATE emergency_vehicle SET status = 'en_route' WHERE name = 'Test Ambulance';

DO $$
DECLARE
    v_name VARCHAR;
BEGIN
    SELECT name INTO v_name FROM sp_find_nearest_vehicle(1, 'ambulance');
    ASSERT v_name = 'Test Ambulance 2', format('Test 8b FAILED: expected Test Ambulance 2, got %s', v_name);
    RAISE NOTICE 'Test 8b PASSED: en_route vehicle excluded, nearest=%', v_name;
END $$;

-- Test 8c: unknown intersection raises an exception
DO $$
DECLARE
    v_raised BOOLEAN := FALSE;
BEGIN
    BEGIN
        PERFORM 1 FROM sp_find_nearest_vehicle(99999, 'ambulance');
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
        RAISE NOTICE 'Test 8c PASSED: exception raised -> %', SQLERRM;
    END;
    IF NOT v_raised THEN
        RAISE EXCEPTION 'Test 8c FAILED: expected exception for unknown intersection';
    END IF;
END $$;

-- ============================================================
-- Cleanup: remove all test data (FK-safe order)
-- ============================================================
DELETE FROM route_recalculation_queue WHERE road_segment_id = 1;
DELETE FROM route_segment WHERE road_segment_id = 1;
DELETE FROM road_status_history WHERE road_segment_id = 1;
DELETE FROM incident_road WHERE road_segment_id = 1;
DELETE FROM incident_report WHERE raw_text = 'Test report raw text';
DELETE FROM incident WHERE description LIKE 'Test incident%';
DELETE FROM emergency_vehicle WHERE name LIKE 'Test Ambulance%';
DELETE FROM traffic_state WHERE road_segment_id = 1;
DELETE FROM road_segment WHERE id = 1;
DELETE FROM intersection WHERE id IN (1, 2);
DELETE FROM zone WHERE id = 1;
DELETE FROM city WHERE id = 1;

\echo 'All procedure tests passed.'
