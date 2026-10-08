# backend/app/modules/routing/dijkstra.py
import heapq
from dataclasses import dataclass, field
from typing import Any

@dataclass
class Edge:
    to_node: int
    weight: float
    road_segment_id: int

@dataclass
class RouteResult:
    path: list[int]
    segments: list[int]
    total_time: float
    total_distance: float

def dijkstra(graph: dict[int, list[Edge]], start: int, end: int) -> RouteResult | None:
    dist = {start: 0.0}
    prev = {}
    pq = [(0.0, start)]
    visited = set()

    while pq:
        d, u = heapq.heappop(pq)
        if u in visited:
            continue
        visited.add(u)
        if u == end:
            break
        for edge in graph.get(u, []):
            v = edge.to_node
            nd = d + edge.weight
            if nd < dist.get(v, float('inf')):
                dist[v] = nd
                prev[v] = (u, edge)
                heapq.heappush(pq, (nd, v))

    if end not in dist:
        return None

    # Reconstruct path
    path = []
    segments = []
    node = end
    while node != start:
        path.append(node)
        prev_node, edge = prev[node]
        segments.append(edge.road_segment_id)
        node = prev_node
    path.append(start)
    path.reverse()
    segments.reverse()

    total_time = dist[end]
    total_distance = sum(edge.weight for edge in [prev[n][1] for n in path[1:]])

    return RouteResult(path=path, segments=segments, total_time=total_time, total_distance=total_distance)

def astar(graph: dict[int, list[Edge]], start: int, end: int, heuristic) -> RouteResult | None:
    # A* with heuristic function
    dist = {start: 0.0}
    prev = {}
    pq = [(heuristic(start, end), 0.0, start)]
    visited = set()

    while pq:
        _, d, u = heapq.heappop(pq)
        if u in visited:
            continue
        visited.add(u)
        if u == end:
            break
        for edge in graph.get(u, []):
            v = edge.to_node
            nd = d + edge.weight
            if nd < dist.get(v, float('inf')):
                dist[v] = nd
                prev[v] = (u, edge)
                heapq.heappush(pq, (nd + heuristic(v, end), nd, v))

    if end not in dist:
        return None

    path = []
    segments = []
    node = end
    while node != start:
        path.append(node)
        prev_node, edge = prev[node]
        segments.append(edge.road_segment_id)
        node = prev_node
    path.append(start)
    path.reverse()
    segments.reverse()

    total_time = dist[end]
    total_distance = sum(edge.weight for edge in [prev[n][1] for n in path[1:]])

    return RouteResult(path=path, segments=segments, total_time=total_time, total_distance=total_distance)
