-- database/01_schema.sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE city (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    bounds GEOMETRY(POLYGON, 4326)
);

CREATE TABLE zone (
    id SERIAL PRIMARY KEY,
    city_id INTEGER NOT NULL REFERENCES city(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    polygon GEOMETRY(POLYGON, 4326) NOT NULL
);

CREATE TABLE intersection (
    id SERIAL PRIMARY KEY,
    zone_id INTEGER NOT NULL REFERENCES zone(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    location GEOMETRY(POINT, 4326) NOT NULL
);

CREATE TABLE road_segment (
    id SERIAL PRIMARY KEY,
    from_intersection_id INTEGER NOT NULL REFERENCES intersection(id) ON DELETE RESTRICT,
    to_intersection_id INTEGER NOT NULL REFERENCES intersection(id) ON DELETE RESTRICT,
    name VARCHAR(200) NOT NULL,
    distance_m FLOAT NOT NULL CHECK (distance_m > 0),
    speed_limit_kmh FLOAT NOT NULL CHECK (speed_limit_kmh > 0 AND speed_limit_kmh <= 200),
    lanes INTEGER NOT NULL CHECK (lanes > 0),
    geom GEOMETRY(LINESTRING, 4326) NOT NULL
);

CREATE TABLE traffic_state (
    road_segment_id INTEGER PRIMARY KEY REFERENCES road_segment(id) ON DELETE RESTRICT,
    travel_time_min FLOAT NOT NULL CHECK (travel_time_min > 0),
    congestion_level VARCHAR(20) NOT NULL CHECK (congestion_level IN ('free','light','moderate','heavy','blocked')),
    last_updated TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE road_status_history (
    id SERIAL PRIMARY KEY,
    road_segment_id INTEGER NOT NULL REFERENCES road_segment(id) ON DELETE RESTRICT,
    old_travel_time FLOAT NOT NULL,
    new_travel_time FLOAT NOT NULL,
    old_congestion_level VARCHAR(20),
    new_congestion_level VARCHAR(20),
    change_reason VARCHAR(200) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE incident (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low','medium','high','critical')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','cleared')),
    description TEXT,
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    cleared_at TIMESTAMP
);

CREATE TABLE incident_road (
    incident_id INTEGER NOT NULL REFERENCES incident(id) ON DELETE RESTRICT,
    road_segment_id INTEGER NOT NULL REFERENCES road_segment(id) ON DELETE RESTRICT,
    impact_level VARCHAR(20) NOT NULL CHECK (impact_level IN ('minor','moderate','severe','total')),
    lanes_blocked INTEGER NOT NULL CHECK (lanes_blocked >= 0),
    delay_minutes FLOAT NOT NULL DEFAULT 0 CHECK (delay_minutes >= 0),
    PRIMARY KEY (incident_id, road_segment_id)
);

CREATE TABLE incident_report (
    id SERIAL PRIMARY KEY,
    incident_id INTEGER REFERENCES incident(id) ON DELETE SET NULL,
    raw_text TEXT NOT NULL,
    extracted_data JSONB,
    extraction_confidence FLOAT CHECK (extraction_confidence >= 0 AND extraction_confidence <= 1),
    extraction_source VARCHAR(20) CHECK (extraction_source IN ('gemini','openai','mock')),
    extraction_fallback BOOLEAN NOT NULL DEFAULT FALSE,
    processed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE emergency_vehicle (
    id SERIAL PRIMARY KEY,
    vehicle_type VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('ambulance','fire_engine','police')),
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'available' CHECK (status IN ('available','en_route','offline')),
    current_zone_id INTEGER REFERENCES zone(id) ON DELETE SET NULL,
    current_intersection_id INTEGER REFERENCES intersection(id) ON DELETE SET NULL,
    location GEOMETRY(POINT, 4326)
);

CREATE TABLE route_request (
    id SERIAL PRIMARY KEY,
    vehicle_id INTEGER NOT NULL REFERENCES emergency_vehicle(id) ON DELETE RESTRICT,
    origin_id INTEGER NOT NULL REFERENCES intersection(id) ON DELETE RESTRICT,
    destination_id INTEGER NOT NULL REFERENCES intersection(id) ON DELETE RESTRICT,
    requested_at TIMESTAMP NOT NULL DEFAULT NOW(),
    priority INTEGER NOT NULL DEFAULT 5 CHECK (priority >= 1 AND priority <= 10)
);

CREATE TABLE network_version (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    snapshot_data JSONB
);

CREATE TABLE route (
    id SERIAL PRIMARY KEY,
    request_id INTEGER NOT NULL REFERENCES route_request(id) ON DELETE RESTRICT,
    route_type VARCHAR(20) NOT NULL CHECK (route_type IN ('fastest','shortest','balanced')),
    total_time_min FLOAT NOT NULL,
    total_distance_m FLOAT NOT NULL,
    actual_time_min FLOAT,
    actual_distance_m FLOAT,
    completed_at TIMESTAMP,
    performance_delta FLOAT GENERATED ALWAYS AS (actual_time_min - total_time_min) STORED,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','stale','completed','cancelled')),
    network_version_id INTEGER REFERENCES network_version(id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE route_segment (
    id SERIAL PRIMARY KEY,
    route_id INTEGER NOT NULL REFERENCES route(id) ON DELETE RESTRICT,
    road_segment_id INTEGER NOT NULL REFERENCES road_segment(id) ON DELETE RESTRICT,
    sequence_order INTEGER NOT NULL,
    estimated_time_min FLOAT NOT NULL,
    UNIQUE (route_id, sequence_order)
);

CREATE TABLE route_recalculation_queue (
    id SERIAL PRIMARY KEY,
    road_segment_id INTEGER NOT NULL REFERENCES road_segment(id) ON DELETE RESTRICT,
    network_version_id INTEGER REFERENCES network_version(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','completed','failed')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP
);
