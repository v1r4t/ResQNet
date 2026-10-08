// frontend/src/types/api.ts
export interface Incident {
  id: number
  type: string
  severity: string
  status: string
  description: string | null
  started_at: string
  cleared_at: string | null
}

export interface RoadSegment {
  road_segment_id: number
  road_name: string
  from_intersection_id: number
  to_intersection_id: number
  distance_m: number
  speed_limit_kmh: number
  travel_time_min: number
  congestion_level: string
  active_incidents: any[]
}

export interface Intersection {
  id: number
  name: string
  location: string
}

export interface NetworkState {
  roads: RoadSegment[]
  intersections: Intersection[]
}

export interface Route {
  id: number
  request_id: number
  route_type: string
  total_time_min: number
  total_distance_m: number
  status: string
  network_version_id: number | null
  created_at: string
  segments: RouteSegment[]
}

export interface RouteSegment {
  sequence_order: number
  road_segment_id: number
  road_name: string
  estimated_time_min: number
}

export interface Vehicle {
  id: number
  vehicle_type: string
  name: string
  status: string
  current_intersection_id: number | null
}
