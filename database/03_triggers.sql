-- database/03_triggers.sql

CREATE OR REPLACE FUNCTION fn_network_version_on_traffic_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.travel_time_min IS DISTINCT FROM NEW.travel_time_min
       OR OLD.congestion_level IS DISTINCT FROM NEW.congestion_level THEN
        UPDATE network_version SET is_active = FALSE WHERE is_active = TRUE;
        INSERT INTO network_version (is_active, snapshot_data) VALUES (TRUE, '{}');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_network_version_on_traffic_change
    BEFORE UPDATE ON traffic_state
    FOR EACH ROW
    WHEN (OLD.travel_time_min IS DISTINCT FROM NEW.travel_time_min
          OR OLD.congestion_level IS DISTINCT FROM NEW.congestion_level)
    EXECUTE FUNCTION fn_network_version_on_traffic_change();

-- Trigger 1: Log traffic state changes to history
CREATE OR REPLACE FUNCTION fn_traffic_state_history()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO road_status_history (
        road_segment_id, old_travel_time, new_travel_time,
        old_congestion_level, new_congestion_level, change_reason
    )
    VALUES (OLD.road_segment_id, OLD.travel_time_min, NEW.travel_time_min,
            OLD.congestion_level, NEW.congestion_level,
            CASE
                WHEN OLD.congestion_level IS DISTINCT FROM NEW.congestion_level
                    THEN OLD.congestion_level || '_to_' || NEW.congestion_level
                ELSE 'travel_time_update'
            END);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_traffic_state_history
    AFTER UPDATE ON traffic_state
    FOR EACH ROW
    WHEN (OLD.travel_time_min IS DISTINCT FROM NEW.travel_time_min
          OR OLD.congestion_level IS DISTINCT FROM NEW.congestion_level)
    EXECUTE FUNCTION fn_traffic_state_history();

-- Trigger 2: Mark routes stale when travel time changes significantly
CREATE OR REPLACE FUNCTION fn_route_invalidation()
RETURNS TRIGGER AS $$
DECLARE
    change_pct FLOAT;
BEGIN
    change_pct := ABS(NEW.travel_time_min - OLD.travel_time_min) / NULLIF(OLD.travel_time_min, 0);
    IF change_pct > 0.20
       OR OLD.congestion_level IS DISTINCT FROM NEW.congestion_level THEN
        UPDATE route SET status = 'stale'
        WHERE status = 'active'
        AND id IN (
            SELECT r.id FROM route r
            JOIN route_segment rs ON r.id = rs.route_id
            WHERE rs.road_segment_id = NEW.road_segment_id
        );
        INSERT INTO route_recalculation_queue (road_segment_id, network_version_id, status)
        SELECT NEW.road_segment_id, id, 'pending'
        FROM network_version WHERE is_active = TRUE ORDER BY id DESC LIMIT 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_route_invalidation
    AFTER UPDATE ON traffic_state
    FOR EACH ROW
    WHEN (OLD.travel_time_min IS DISTINCT FROM NEW.travel_time_min
          OR OLD.congestion_level IS DISTINCT FROM NEW.congestion_level)
    EXECUTE FUNCTION fn_route_invalidation();

-- Trigger 3: Recalculate road impact when incident_road is inserted
CREATE OR REPLACE FUNCTION fn_incident_road_update()
RETURNS TRIGGER AS $$
BEGIN
    CALL sp_recalculate_road_impact(NEW.road_segment_id);
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
