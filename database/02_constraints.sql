-- database/02_constraints.sql
CREATE INDEX idx_intersection_location ON intersection USING GIST (location);
CREATE INDEX idx_road_segment_geom ON road_segment USING GIST (geom);
CREATE INDEX idx_vehicle_location ON emergency_vehicle USING GIST (location);
CREATE INDEX idx_traffic_state_road_id ON traffic_state (road_segment_id);
CREATE INDEX idx_road_status_history_road_id ON road_status_history (road_segment_id);
CREATE INDEX idx_road_status_history_changed_at ON road_status_history (changed_at);
CREATE INDEX idx_incident_status ON incident (status);
CREATE INDEX idx_incident_road_road_id ON incident_road (road_segment_id);
CREATE INDEX idx_route_request_vehicle_id ON route_request (vehicle_id);
CREATE INDEX idx_route_segment_route_id ON route_segment (route_id);
CREATE INDEX idx_incident_report_processed ON incident_report (processed_at);
CREATE INDEX idx_network_version_active ON network_version (is_active);
CREATE INDEX idx_route_network_version ON route (network_version_id);
