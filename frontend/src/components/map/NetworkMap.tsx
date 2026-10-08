// frontend/src/components/map/NetworkMap.tsx
import { useEffect, useRef } from 'react'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

interface NetworkMapProps {
  roads: any[]
  intersections: any[]
  incidents?: any[]
  routes?: any[]
  vehicles?: any[]
}

export default function NetworkMap({ roads, intersections, incidents, routes, vehicles }: NetworkMapProps) {
  const mapContainer = useRef<HTMLDivElement>(null)
  const map = useRef<maplibregl.Map | null>(null)

  useEffect(() => {
    if (!mapContainer.current) return

    map.current = new maplibre-gl.Map({
      container: mapContainer.current,
      style: 'https://demotiles.maplibre.org/style.json',
      center: [77.15, 13.0],
      zoom: 12
    })

    map.current.on('load', () => {
      // Add road layer
      map.current?.addSource('roads', {
        type: 'geojson',
        data: {
          type: 'FeatureCollection',
          features: roads.map((road) => ({
            type: 'Feature',
            properties: {
              name: road.road_name,
              congestion: road.congestion_level,
              travel_time: road.travel_time_min,
            },
            geometry: {
              type: 'LineString',
              coordinates: road._coords || [
                [road.from_intersection_id, road.from_intersection_id],
                [road.to_intersection_id, road.to_intersection_id],
              ],
            },
          })),
        },
      })

      map.current?.addLayer({
        id: 'roads-layer',
        type: 'line',
        source: 'roads',
        paint: {
          'line-color': [
            'match',
            ['get', 'congestion'],
            'free', '#22c55e',
            'light', '#84cc16',
            'moderate', '#eab308',
            'heavy', '#f97316',
            'blocked', '#ef4444',
            '#6b7280',
          ],
          'line-width': 3,
        },
      })

      // Add intersections layer
      map.current?.addSource('intersections', {
        type: 'geojson',
        data: {
          type: 'FeatureCollection',
          features: intersections.map((inter) => ({
            type: 'Feature',
            properties: { name: inter.name },
            geometry: {
              type: 'Point',
              coordinates: inter._coords || [0, 0],
            },
          })),
        },
      })

      map.current?.addLayer({
        id: 'intersections-layer',
        type: 'circle',
        source: 'intersections',
        paint: {
          'circle-radius': 5,
          'circle-color': '#3b82f6',
          'circle-stroke-width': 2,
          'circle-stroke-color': '#ffffff',
        },
      })

      // Add incidents layer
      if (incidents && incidents.length > 0) {
        map.current?.addSource('incidents', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: incidents.map((inc) => ({
              type: 'Feature',
              properties: {
                type: inc.type,
                severity: inc.severity,
                description: inc.description,
              },
              geometry: {
                type: 'Point',
                coordinates: inc._coords || [0, 0],
              },
            })),
          },
        })

        map.current?.addLayer({
          id: 'incidents-layer',
          type: 'circle',
          source: 'incidents',
          paint: {
            'circle-radius': 8,
            'circle-color': [
              'match',
              ['get', 'severity'],
              'critical', '#dc2626',
              'high', '#f97316',
              'medium', '#eab308',
              'low', '#22c55e',
              '#6b7280',
            ],
            'circle-stroke-width': 2,
            'circle-stroke-color': '#ffffff',
          },
        })
      }

      // Add vehicles layer
      if (vehicles && vehicles.length > 0) {
        map.current?.addSource('vehicles', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: vehicles.map((veh) => ({
              type: 'Feature',
              properties: {
                name: veh.name,
                type: veh.vehicle_type,
                status: veh.status,
              },
              geometry: {
                type: 'Point',
                coordinates: veh._coords || [0, 0],
              },
            })),
          },
        })

        map.current?.addLayer({
          id: 'vehicles-layer',
          type: 'symbol',
          source: 'vehicles',
          layout: {
            'icon-image': [
              'match',
              ['get', 'type'],
              'ambulance', 'hospital-15',
              'fire_engine', 'fire-station-15',
              'police', 'police-15',
              'marker-15',
            ],
            'text-field': ['get', 'name'],
            'text-offset': [0, 1.5],
            'text-anchor': 'top',
          },
        })
      }

      // Add routes layer
      if (routes && routes.length > 0) {
        map.current?.addSource('routes', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: routes.map((route) => ({
              type: 'Feature',
              properties: {
                id: route.id,
                status: route.status,
                total_time: route.total_time_min,
              },
              geometry: {
                type: 'LineString',
                coordinates: route._coords || [
                  [route.origin_id, route.origin_id],
                  [route.destination_id, route.destination_id],
                ],
              },
            })),
          },
        })

        map.current?.addLayer({
          id: 'routes-layer',
          type: 'line',
          source: 'routes',
          paint: {
            'line-color': [
              'match',
              ['get', 'status'],
              'active', '#3b82f6',
              'completed', '#22c55e',
              'cancelled', '#ef4444',
              'stale', '#f59e0b',
              '#6b7280',
            ],
            'line-width': 4,
            'line-dasharray': [2, 1],
          },
        })
      }
    })

    return () => { map.current?.remove() }
  }, [roads, intersections, incidents, routes, vehicles])

  return <div ref={mapContainer} className="w-full h-[600px] rounded-lg" />
}
