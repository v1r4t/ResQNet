# backend/tests/test_routing.py
from app.modules.routing.dijkstra import dijkstra, astar, Edge

def test_dijkstra_simple_path():
    graph = {
        1: [Edge(2, 5.0, 101)],
        2: [Edge(3, 3.0, 102)],
        3: []
    }
    result = dijkstra(graph, 1, 3)
    assert result is not None
    assert result.path == [1, 2, 3]
    assert result.segments == [101, 102]
    assert result.total_time == 8.0

def test_dijkstra_no_path():
    graph = {
        1: [Edge(2, 5.0, 101)],
        2: [],
        3: []
    }
    result = dijkstra(graph, 1, 3)
    assert result is None

def test_dijkstra_multiple_paths():
    graph = {
        1: [Edge(2, 1.0, 101), Edge(3, 10.0, 102)],
        2: [Edge(3, 1.0, 103)],
        3: []
    }
    result = dijkstra(graph, 1, 3)
    assert result is not None
    assert result.path == [1, 2, 3]
    assert result.total_time == 2.0

def test_astar_simple_path():
    graph = {
        1: [Edge(2, 5.0, 101)],
        2: [Edge(3, 3.0, 102)],
        3: []
    }
    def heuristic(a, b):
        return 0.0  # Dijkstra equivalent
    result = astar(graph, 1, 3, heuristic)
    assert result is not None
    assert result.path == [1, 2, 3]
    assert result.total_time == 8.0
