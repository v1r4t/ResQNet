-- database/03_triggers.sql

-- Trigger 1: Log traffic state changes to history
CREATE OR REPLACE FUNCTION fn_traffic_state_history()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO road_status_history (road_segment_id, old_travel_time, new_travel_time, change_reason)
    VALUES (OLD.road_segment_id, OLD.travel_time_min, NEW.travel_time_min, 'traffic_state_update');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_traffic_state_history
    AFTER UPDATE ON traffic_state
    FOR EACH ROW
    EXECUTE FUNCTION fn_traffic_state_history();

-- Trigger 2: Mark routes stale when travel time changes significantly
CREATE OR REPLACE FUNCTION fn_route_invalidation()
RETURNS TRIGGER AS $$
DECLARE
    change_pct FLOAT;
BEGIN
    change_pct := ABS(NEW.travel_time_min - OLD.travel_time_min) / OLD.travel_time_min;
    IF change_pct > 0.20 THEN
        UPDATE route SET status = 'stale'
        WHERE status = 'active'
        AND id IN (
            SELECT r.id FROM route r
            JOIN route_segment rs ON r.id = rs.route_id
            WHERE rs.road_segment_id = NEW.road_segment_id
        );
        INSERT INTO route_recalculation_queue (road_segment_id, status)
        VALUES (NEW.road_segment_id, 'pending');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_route_invalidation
    AFTER UPDATE ON traffic_state
    FOR EACH ROW
    EXECUTE FUNCTION fn_route_invalidation();

-- Trigger 3: Recalculate road impact when incident_road is inserted
CREATE OR REPLACE FUNCTION fn_incident_road_update()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM sp_recalculate_road_impact(NEW.road_segment_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_incident_road_update
    AFTER INSERT ON incident_road
    FOR EACH ROW
    EXECUTE FUNCTION fn_incident_road_update();

-- Trigger 4: Sync vehicle location geometry
CREATE OR REPLACE FUNCTION fn_vehicle_location_sync()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.current_intersection_id IS NOT NULL THEN
        SELECT location INTO NEW.location
        FROM intersection WHERE id = NEW.current_intersection_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_vehicle_location_sync
    BEFORE UPDATE ON emergency_vehicle
    FOR EACH ROW
    WHEN (OLD.current_intersection_id IS DISTINCT FROM NEW.current_intersection_id)
    EXECUTE FUNCTION fn_vehicle_location_sync();

-- Stub for sp_recalculate_road_impact (will be replaced in Task 4)
CREATE OR REPLACE PROCEDURE sp_recalculate_road_impact(p_road_segment_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    NULL; -- Placeholder
END;
$$;
