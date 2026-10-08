-- database/05_views.sql

-- View 1: Current network state
CREATE OR REPLACE VIEW v_current_network AS
SELECT rs.id AS road_segment_id,
       rs.name AS road_name,
       rs.from_intersection_id,
       rs.to_intersection_id,
       rs.distance_m,
       rs.speed_limit_kmh,
       ts.travel_time_min,
       ts.congestion_level,
       ts.last_updated,
       COALESCE(json_agg(json_build_object(
           'incident_id', i.id,
           'type', i.type,
           'severity', i.severity,
           'impact_level', ir.impact_level
       )) FILTER (WHERE i.id IS NOT NULL), '[]') AS active_incidents
FROM road_segment rs
JOIN traffic_state ts ON rs.id = ts.road_segment_id
LEFT JOIN incident_road ir ON rs.id = ir.road_segment_id
LEFT JOIN incident i ON ir.incident_id = i.id AND i.status = 'active'
GROUP BY rs.id, ts.travel_time_min, ts.congestion_level, ts.last_updated;

-- View 2: Congestion hotspots (aggregated per zone)
-- Column list changed from the original definition, so drop before replacing.
DROP VIEW IF EXISTS v_congestion_hotspots;
CREATE OR REPLACE VIEW v_congestion_hotspots AS
SELECT z.name AS zone_name,
       COUNT(*) AS hotspot_count,
       AVG(ts.travel_time_min) AS avg_travel_time,
       AVG(ts.travel_time_min / ((rs.distance_m / 1000.0) / rs.speed_limit_kmh * 60.0)) AS avg_congestion_ratio
FROM traffic_state ts
JOIN road_segment rs ON ts.road_segment_id = rs.id
JOIN intersection i ON rs.from_intersection_id = i.id
JOIN zone z ON i.zone_id = z.id
WHERE ts.travel_time_min > 2.0 * ((rs.distance_m / 1000.0) / rs.speed_limit_kmh * 60.0)
GROUP BY z.name;

-- View 3: Incident frequency
CREATE OR REPLACE VIEW v_incident_frequency AS
SELECT rs.id AS road_segment_id,
       rs.name AS road_name,
       i.type AS incident_type,
       COUNT(*) AS incident_count,
       DATE_TRUNC('day', i.started_at) AS day
FROM incident i
JOIN incident_road ir ON i.id = ir.incident_id
JOIN road_segment rs ON ir.road_segment_id = rs.id
GROUP BY rs.id, rs.name, i.type, DATE_TRUNC('day', i.started_at);

-- View 4: Route performance (completed routes only)
CREATE OR REPLACE VIEW v_route_performance AS
SELECT r.id AS route_id,
       r.route_type,
       r.total_time_min AS estimated_time,
       r.actual_time_min,
       r.performance_delta,
       r.status,
       ev.vehicle_type,
       r.created_at
FROM route r
JOIN route_request rr ON r.request_id = rr.id
JOIN emergency_vehicle ev ON rr.vehicle_id = ev.id
WHERE r.status = 'completed';
