-- database/tests/test_views.sql
-- Test that all views exist and are queryable

SELECT COUNT(*) FROM v_current_network;
-- Expected: Number of road segments with traffic state

SELECT COUNT(*) FROM v_congestion_hotspots;
-- Expected: 0 (no congestion in seed data)

SELECT COUNT(*) FROM v_incident_frequency;
-- Expected: 0 (no incidents in seed data)

SELECT COUNT(*) FROM v_route_performance;
-- Expected: 0 (no completed routes in seed data)
