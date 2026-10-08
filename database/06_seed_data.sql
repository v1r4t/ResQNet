-- database/06_seed_data.sql
-- Synthetic city grid: 8x8 grid of intersections with named zones

INSERT INTO city (name, bounds) VALUES ('ResQNet City', ST_GeomFromText('POLYGON((77.0 12.9, 77.0 13.1, 77.3 13.1, 77.3 12.9, 77.0 12.9))', 4326));

-- Zones
INSERT INTO zone (city_id, name, polygon) VALUES
(1, 'Downtown', ST_GeomFromText('POLYGON((77.05 12.95, 77.05 13.0, 77.15 13.0, 77.15 12.95, 77.05 12.95))', 4326)),
(1, 'North District', ST_GeomFromText('POLYGON((77.05 13.0, 77.05 13.05, 77.15 13.05, 77.15 13.0, 77.05 13.0))', 4326)),
(1, 'South District', ST_GeomFromText('POLYGON((77.05 12.9, 77.05 12.95, 77.15 12.95, 77.15 12.9, 77.05 12.9))', 4326)),
(1, 'East Industrial', ST_GeomFromText('POLYGON((77.15 12.9, 77.15 13.0, 77.25 13.0, 77.25 12.9, 77.15 12.9))', 4326)),
(1, 'West Residential', ST_GeomFromText('POLYGON((77.0 12.9, 77.0 13.0, 77.05 13.0, 77.05 12.9, 77.0 12.9))', 4326)),
(1, 'Airport Corridor', ST_GeomFromText('POLYGON((77.15 13.0, 77.15 13.05, 77.25 13.05, 77.25 13.0, 77.15 13.0))', 4326)),
(1, 'Tech Park', ST_GeomFromText('POLYGON((77.0 13.0, 77.0 13.05, 77.05 13.05, 77.05 13.0, 77.0 13.0))', 4326)),
(1, 'Outer Ring', ST_GeomFromText('POLYGON((77.0 12.9, 77.0 13.1, 77.3 13.1, 77.3 12.9, 77.0 12.9))', 4326));

-- Intersections (8x8 grid = 64 intersections)
-- Naming: A1-A8, B1-B8, ..., H1-H8
DO $$
DECLARE
    row_char CHAR;
    col_num INTEGER;
    zone_id INTEGER;
    lat FLOAT;
    lon FLOAT;
BEGIN
    FOR row_char IN SELECT chr(64 + i) FROM generate_series(1, 8) i LOOP
        FOR col_num IN 1..8 LOOP
            lat := 12.9 + (ASCII(row_char) - 65) * 0.0125;
            lon := 77.0 + (col_num - 1) * 0.0375;

            zone_id := CASE
                WHEN lat >= 13.0 AND lon >= 77.15 THEN 6  -- Airport Corridor
                WHEN lat >= 13.0 AND lon < 77.05 THEN 7    -- Tech Park
                WHEN lat >= 13.0 THEN 2                    -- North District
                WHEN lat < 12.95 AND lon >= 77.15 THEN 4   -- East Industrial
                WHEN lat < 12.95 AND lon < 77.05 THEN 5    -- West Residential
                WHEN lat < 12.95 THEN 3                    -- South District
                WHEN lon >= 77.15 THEN 4                   -- East Industrial
                WHEN lon < 77.05 THEN 5                    -- West Residential
                ELSE 1                                     -- Downtown
            END;

            INSERT INTO intersection (zone_id, name, location)
            VALUES (zone_id, row_char || col_num, ST_SetSRID(ST_MakePoint(lon, lat), 4326));
        END LOOP;
    END LOOP;
END $$;

-- Road segments (grid: horizontal + vertical connections)
-- Horizontal roads
DO $$
DECLARE
    row_char CHAR;
    col_num INTEGER;
    from_id INTEGER;
    to_id INTEGER;
    road_name TEXT;
BEGIN
    FOR row_char IN SELECT chr(64 + i) FROM generate_series(1, 8) i LOOP
        FOR col_num IN 1..7 LOOP
            SELECT id INTO from_id FROM intersection WHERE name = row_char || col_num;
            SELECT id INTO to_id FROM intersection WHERE name = row_char || (col_num + 1);
            road_name := row_char || col_num || '-' || row_char || (col_num + 1);

            INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
            VALUES (from_id, to_id, road_name, 500, 60, 2,
                ST_SetSRID(ST_MakeLine(
                    (SELECT location FROM intersection WHERE id = from_id),
                    (SELECT location FROM intersection WHERE id = to_id)
                ), 4326));

            -- Bidirectional
            INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
            VALUES (to_id, from_id, road_name || ' (reverse)', 500, 60, 2,
                ST_SetSRID(ST_MakeLine(
                    (SELECT location FROM intersection WHERE id = to_id),
                    (SELECT location FROM intersection WHERE id = from_id)
                ), 4326));
        END LOOP;
    END LOOP;
END $$;

-- Vertical roads
DO $$
DECLARE
    row_idx INTEGER;
    col_num INTEGER;
    from_id INTEGER;
    to_id INTEGER;
    road_name TEXT;
BEGIN
    FOR row_idx IN 1..7 LOOP
        FOR col_num IN 1..8 LOOP
            SELECT id INTO from_id FROM intersection WHERE name = chr(64 + row_idx) || col_num;
            SELECT id INTO to_id FROM intersection WHERE name = chr(64 + row_idx + 1) || col_num;
            road_name := chr(64 + row_idx) || col_num || '-' || chr(64 + row_idx + 1) || col_num;

            INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
            VALUES (from_id, to_id, road_name, 500, 60, 2,
                ST_SetSRID(ST_MakeLine(
                    (SELECT location FROM intersection WHERE id = from_id),
                    (SELECT location FROM intersection WHERE id = to_id)
                ), 4326));

            INSERT INTO road_segment (from_intersection_id, to_intersection_id, name, distance_m, speed_limit_kmh, lanes, geom)
            VALUES (to_id, from_id, road_name || ' (reverse)', 500, 60, 2,
                ST_SetSRID(ST_MakeLine(
                    (SELECT location FROM intersection WHERE id = to_id),
                    (SELECT location FROM intersection WHERE id = from_id)
                ), 4326));
        END LOOP;
    END LOOP;
END $$;

-- Traffic state for all road segments
INSERT INTO traffic_state (road_segment_id, travel_time_min, congestion_level)
SELECT id, (distance_m / 1000.0) / speed_limit_kmh * 60.0, 'free'
FROM road_segment;

-- Emergency vehicles
INSERT INTO emergency_vehicle (vehicle_type, name, status, current_zone_id, current_intersection_id, location) VALUES
('ambulance', 'Ambulance-1', 'available', 1, 1, (SELECT location FROM intersection WHERE id = 1)),
('ambulance', 'Ambulance-2', 'available', 2, 10, (SELECT location FROM intersection WHERE id = 10)),
('fire_engine', 'Fire-1', 'available', 4, 28, (SELECT location FROM intersection WHERE id = 28)),
('police', 'Police-1', 'available', 1, 5, (SELECT location FROM intersection WHERE id = 5)),
('police', 'Police-2', 'available', 3, 20, (SELECT location FROM intersection WHERE id = 20));

-- Initial network version
INSERT INTO network_version (is_active, snapshot_data) VALUES (TRUE, '{}');
