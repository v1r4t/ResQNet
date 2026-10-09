-- database/04_procedures.sql

-- The following routines were originally created as PROCEDUREs but are being
-- converted to FUNCTIONs so they can return result sets. PostgreSQL routines
-- share a namespace, so the old procedure versions must be dropped first.
-- These drops are no-ops on a fresh database and idempotent on re-runs.
DROP PROCEDURE IF EXISTS sp_get_analytics_congestion(INTEGER);
DROP PROCEDURE IF EXISTS sp_find_nearest_vehicle(INTEGER, VARCHAR);

-- Procedure 1: Process incident report
CREATE OR REPLACE PROCEDURE sp_process_incident_report(p_report_id INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_incident_id INTEGER;
    v_extracted JSONB;
    v_road_name TEXT;
    v_road_id INTEGER;
    v_type TEXT;
    v_severity TEXT;
    v_lanes_blocked INTEGER;
    v_delay_minutes FLOAT;
    v_description TEXT;
    v_road_count INTEGER;
BEGIN
    SELECT extracted_data INTO v_extracted FROM incident_report WHERE id = p_report_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Incident report % does not exist', p_report_id;
    END IF;
    IF v_extracted IS NULL THEN
        RAISE EXCEPTION 'No extracted data for report %', p_report_id;
    END IF;

    v_type := v_extracted->>'type';
    v_severity := v_extracted->>'severity';
    v_road_name := v_extracted->>'road';
    v_lanes_blocked := COALESCE((v_extracted->>'lanes_blocked')::INTEGER, 1);
    v_delay_minutes := GREATEST(COALESCE((v_extracted->>'delay')::FLOAT, 0.0), 0.0);
    v_description := v_extracted->>'description';

    INSERT INTO incident (type, severity, status, description)
    VALUES (v_type, v_severity, 'active', v_description)
    RETURNING id INTO v_incident_id;

    UPDATE incident_report SET incident_id = v_incident_id WHERE id = p_report_id;

    SELECT COUNT(*) INTO v_road_count
    FROM road_segment WHERE name ILIKE v_road_name;
    IF v_road_count = 0 THEN
        RAISE EXCEPTION 'No road found matching location: %', v_road_name;
    ELSIF v_road_count > 1 THEN
        RAISE EXCEPTION 'Ambiguous road location: %', v_road_name;
    END IF;

    FOR v_road_id IN
        SELECT id FROM road_segment WHERE name ILIKE v_road_name
    LOOP
        INSERT INTO incident_road (incident_id, road_segment_id, impact_level, lanes_blocked, delay_minutes)
        VALUES (v_incident_id, v_road_id,
            CASE v_severity
                WHEN 'low' THEN 'minor'
                WHEN 'medium' THEN 'moderate'
                WHEN 'high' THEN 'severe'
                WHEN 'critical' THEN 'total'
            END,
            v_lanes_blocked,
            v_delay_minutes
        );
    END LOOP;

    IF v_road_count = 0 THEN
        RAISE WARNING 'No roads found matching name: %', v_road_name;
    END IF;
END;
$$;

-- Procedure 2: Recalculate road impact from all active incidents
CREATE OR REPLACE PROCEDURE sp_recalculate_road_impact(p_road_segment_id INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_base_time FLOAT;
    v_multiplier FLOAT := 1.0;
    v_incident RECORD;
BEGIN
    SELECT (rs.distance_m / 1000.0) / rs.speed_limit_kmh * 60.0
    INTO v_base_time
    FROM road_segment rs WHERE rs.id = p_road_segment_id;

    FOR v_incident IN
        SELECT ir.impact_level, ir.lanes_blocked, ir.delay_minutes, rs.lanes
        FROM incident_road ir
        JOIN incident i ON ir.incident_id = i.id
        JOIN road_segment rs ON ir.road_segment_id = rs.id
        WHERE ir.road_segment_id = p_road_segment_id AND i.status = 'active'
    LOOP
        v_multiplier := v_multiplier * CASE v_incident.impact_level
            WHEN 'minor' THEN 1.2
            WHEN 'moderate' THEN 1.5
            WHEN 'severe' THEN 2.0
            WHEN 'total' THEN 5.0
        END;
        IF v_incident.lanes_blocked >= v_incident.lanes THEN
            v_multiplier := v_multiplier * 5.0;
        END IF;
        IF v_base_time > 0 THEN
            v_multiplier := v_multiplier + (v_incident.delay_minutes / v_base_time);
        END IF;
    END LOOP;

    -- Cap congestion multiplier to prevent astronomical values
    v_multiplier := LEAST(v_multiplier, 20.0);

    INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level)
    VALUES (p_road_segment_id, v_base_time * v_multiplier,
        CASE
            WHEN v_multiplier <= 1.2 THEN 'free'
            WHEN v_multiplier <= 1.5 THEN 'light'
            WHEN v_multiplier <= 2.0 THEN 'moderate'
            WHEN v_multiplier <= 5.0 THEN 'heavy'
            ELSE 'blocked'
        END
    )
    ON CONFLICT (road_segment_id) DO UPDATE
    SET travel_time_min = EXCLUDED.travel_time_min,
        congestion_level = EXCLUDED.congestion_level,
        last_updated = NOW();
END;
$$;

-- Procedure 3: Clear incident
CREATE OR REPLACE PROCEDURE sp_clear_incident(p_incident_id INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_road_id INTEGER;
BEGIN
    UPDATE incident SET status = 'cleared', cleared_at = NOW() WHERE id = p_incident_id;

    FOR v_road_id IN
        SELECT road_segment_id FROM incident_road WHERE incident_id = p_incident_id
    LOOP
        CALL sp_recalculate_road_impact(v_road_id);
    END LOOP;
END;
$$;

-- Function 4: Get congestion analytics (returns a result set)
CREATE OR REPLACE FUNCTION sp_get_analytics_congestion(p_hours_back INTEGER)
RETURNS TABLE(zone_name VARCHAR, avg_travel_time FLOAT, road_count BIGINT)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT z.name,
           AVG(ts.travel_time_min)::FLOAT,
           COUNT(*)::BIGINT
    FROM traffic_state ts
    JOIN road_segment rs ON ts.road_segment_id = rs.id
    JOIN intersection i ON rs.from_intersection_id = i.id
    JOIN zone z ON i.zone_id = z.id
    WHERE ts.last_updated > NOW() - INTERVAL '1 hour' * p_hours_back
    GROUP BY z.name;
END;
$$;

-- Function 5: Find nearest available vehicle (returns a result set)
CREATE OR REPLACE FUNCTION sp_find_nearest_vehicle(p_intersection_id INTEGER, p_vehicle_type VARCHAR)
RETURNS TABLE(id INTEGER, name VARCHAR, vehicle_type VARCHAR, distance_m FLOAT)
LANGUAGE plpgsql AS $$
DECLARE
    v_location GEOMETRY;
BEGIN
    SELECT i.location INTO v_location FROM intersection i WHERE i.id = p_intersection_id;

    IF v_location IS NULL THEN
        RAISE EXCEPTION 'No location found for intersection %', p_intersection_id;
    END IF;

    RETURN QUERY
    SELECT ev.id, ev.name, ev.vehicle_type,
           ST_Distance(ev.location, v_location)::FLOAT
    FROM emergency_vehicle ev
    WHERE ev.vehicle_type = p_vehicle_type AND ev.status = 'available'
    ORDER BY ST_Distance(ev.location, v_location)
    LIMIT 1;
END;
$$;
