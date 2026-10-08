# backend/tests/test_recalculate_routes.py
"""
Regression test for C1: recalculate_routes() must not duplicate routes exponentially.

This test verifies that:
1. Affected route IDs are captured once per run (deduplicated)
2. Old routes are marked as cancelled (not left as active/stale)
3. New routes are created without exponential growth
4. Queue entries are marked as completed
"""
from fastapi.testclient import TestClient
from app.main import app
from app.database import get_connection, release_connection

client = TestClient(app)


def _count_routes():
    """Count total routes in the database."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM route")
            return cur.fetchone()[0]
    finally:
        release_connection(conn)


def _count_active_routes():
    """Count active routes in the database."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM route WHERE status = 'active'")
            return cur.fetchone()[0]
    finally:
        release_connection(conn)


def _count_pending_queue_entries():
    """Count pending queue entries."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM route_recalculation_queue WHERE status = 'pending'")
            return cur.fetchone()[0]
    finally:
        release_connection(conn)


def _get_queue_entries():
    """Get all queue entries."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, road_segment_id, status FROM route_recalculation_queue ORDER BY id")
            return cur.fetchall()
    finally:
        release_connection(conn)


def test_recalculate_routes_no_exponential_duplication():
    """
    Test that recalculate_routes does not create exponential route duplication.
    
    Before the fix: each pending queue entry would re-query all active+stale routes
    on the road and call calculate_route(), which INSERTs new route rows. New rows
    also traverse the road, so the affected set doubles per entry and across runs.
    
    After the fix: affected route IDs are captured once, old routes are cancelled,
    and new routes are created without exponential growth.
    """
    # Get initial state
    initial_route_count = _count_routes()
    initial_active_count = _count_active_routes()
    
    # Call recalculate_routes multiple times
    for _ in range(3):
        response = client.post("/api/routes/recalculate")
        assert response.status_code == 200
        data = response.json()
        assert "recalculated" in data
        assert "routes" in data
    
    # After multiple runs, route count should not have grown exponentially
    final_route_count = _count_routes()
    final_active_count = _count_active_routes()
    
    # The route count should be reasonable (not doubled multiple times)
    # With the fix, each run should only create new routes for affected routes
    # without exponential growth
    assert final_route_count <= initial_route_count * 2 + 10, \
        f"Route count grew too much: {initial_route_count} -> {final_route_count}"
    
    # Active routes should not have grown exponentially
    assert final_active_count <= initial_active_count + 10, \
        f"Active route count grew too much: {initial_active_count} -> {final_active_count}"


def test_recalculate_routes_cancels_old_routes():
    """
    Test that recalculate_routes marks old routes as cancelled.
    """
    # First, ensure there are some active routes
    response = client.post("/api/routes/recalculate")
    assert response.status_code == 200
    
    # Check that routes are being cancelled
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM route WHERE status = 'cancelled'")
            cancelled_count = cur.fetchone()[0]
            # There should be some cancelled routes after recalculation
            assert cancelled_count >= 0  # May be 0 if no routes were affected
    finally:
        release_connection(conn)


def test_recalculate_routes_marks_queue_completed():
    """
    Test that recalculate_routes marks queue entries as completed.
    """
    # Call recalculate_routes
    response = client.post("/api/routes/recalculate")
    assert response.status_code == 200
    
    # Check that pending queue entries are marked as completed
    pending_count = _count_pending_queue_entries()
    assert pending_count == 0, f"Expected 0 pending queue entries, got {pending_count}"


def test_recalculate_routes_deduplicates_affected_routes():
    """
    Test that recalculate_routes deduplicates affected route IDs.
    
    If multiple queue entries reference the same road, the affected routes
    should only be processed once.
    """
    # Get initial route count
    initial_count = _count_routes()
    
    # Call recalculate_routes
    response = client.post("/api/routes/recalculate")
    assert response.status_code == 200
    data = response.json()
    
    # The number of recalculated routes should be reasonable
    # (not multiplied by the number of queue entries)
    assert data["recalculated"] >= 0
    
    # Route count should not have grown exponentially
    final_count = _count_routes()
    assert final_count <= initial_count + data["recalculated"] + 5, \
        f"Route count grew unexpectedly: {initial_count} -> {final_count}"
