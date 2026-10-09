-- database/06_seed_data.sql
-- Synthetic city grid for routing simulation. This is not a Bangalore road dataset.

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
    row_idx INTEGER;
    col_num INTEGER;
    zone_id INTEGER;
    lat FLOAT;
    lon FLOAT;
BEGIN
    FOR row_char IN SELECT chr(64 + i) FROM generate_series(1, 8) i LOOP
        row_idx := ASCII(row_char) - 64;
        FOR col_num IN 1..8 LOOP
            lat := 12.9 + (row_idx - 1) * 0.0125;   -- rows 1..8 -> 12.9 .. 12.9875
            lon := 77.0 + (col_num - 1) * 0.0375;   -- cols 1..8 -> 77.0 .. 77.2625

            -- Zone assignment over the ACTUAL 8x8 grid extent.
            -- Outer Ring is the outermost ring (border areas); the remaining interior
            -- (rows 2-7, cols 2-7) is split into the 7 named districts:
            --   top band    (rows 6-7): Tech Park | North District | Airport Corridor
            --   left band   (cols 2-3): West Residential
            --   right band  (cols 6-7): East Industrial
            --   bottom band (rows 2-3, cols 4-5): South District
            --   center      (rows 4-5, cols 4-5): Downtown
            zone_id := CASE
                WHEN row_idx = 1 OR row_idx = 8 OR col_num = 1 OR col_num = 8 THEN 8  -- Outer Ring (border)
                WHEN row_idx >= 6 AND col_num <= 3 THEN 7   -- Tech Park (top-left)
                WHEN row_idx >= 6 AND col_num <= 5 THEN 2   -- North District (top-center)
                WHEN row_idx >= 6 THEN 6                    -- Airport Corridor (top-right)
                WHEN col_num <= 3 THEN 5                    -- West Residential (left)
                WHEN col_num >= 6 THEN 4                    -- East Industrial (right)
                WHEN row_idx <= 3 THEN 3                    -- South District (bottom-center)
                ELSE 1                                      -- Downtown (center)
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

-- Keep each vehicle's zone consistent with the zone of its current intersection
UPDATE emergency_vehicle ev
SET current_zone_id = i.zone_id
FROM intersection i
WHERE ev.current_intersection_id = i.id;

-- Initial network version
INSERT INTO network_version (is_active, snapshot_data) VALUES (TRUE, '{}');
