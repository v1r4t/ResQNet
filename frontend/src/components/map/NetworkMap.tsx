// frontend/src/components/map/NetworkMap.tsx
import { useEffect, useRef } from 'react'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { LiveRoute } from '../../api/live'

interface NetworkMapProps {
  roads: any[]
  intersections: any[]
  incidents?: any[]
  routes?: any[]
  liveRoute?: LiveRoute | null
  vehicles?: any[]
}

// Fast raster base style that loads instantly with zero external style.json latency
const OPEN_STREET_MAP_STYLE: maplibregl.StyleSpecification = {
  version: 8,
  sources: {
    'open-street-map': {
      type: 'raster',
      tiles: [
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
      ],
      tileSize: 256,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }
  },
  layers: [
    {
      id: 'open-street-map-layer',
      type: 'raster',
      source: 'open-street-map',
      minzoom: 0,
      maxzoom: 20
    }
  ]
}

export default function NetworkMap({ roads, intersections, incidents, routes, liveRoute, vehicles }: NetworkMapProps) {
  const mapContainer = useRef<HTMLDivElement>(null)
  const map = useRef<maplibregl.Map | null>(null)
  const isLoaded = useRef<boolean>(false)

  // Coordinates come from PostGIS. Do not reconstruct missing points from
  // intersection names: that turns missing data into a misleading grid.
  const getCoordMap = () => {
    const mapCoords = new Map<number, [number, number]>()
    intersections.forEach((inter) => {
      if (inter.lon != null && inter.lat != null) {
        mapCoords.set(inter.id, [Number(inter.lon), Number(inter.lat)])
      }
    })
    return mapCoords
  }

  const buildRoadsGeoJSON = (coordMap: Map<number, [number, number]>) => {
    return {
      type: 'FeatureCollection' as const,
      features: (roads || []).flatMap((road) => {
        const fromCoord = coordMap.get(road.from_intersection_id)
        const toCoord = coordMap.get(road.to_intersection_id)
        if (!fromCoord || !toCoord) return []
        return {
          type: 'Feature' as const,
          properties: {
            id: road.road_segment_id,
            name: road.road_name,
            congestion: road.congestion_level,
            travel_time: road.travel_time_min,
          },
          geometry: {
            type: 'LineString' as const,
            coordinates: road.geometry?.coordinates || [fromCoord, toCoord],
          },
        }
      }),
    }
  }

  const buildIntersectionsGeoJSON = (coordMap: Map<number, [number, number]>) => {
    return {
      type: 'FeatureCollection' as const,
      features: (intersections || []).flatMap((inter) => {
        const coords = coordMap.get(inter.id)
        if (!coords) return []
        return {
          type: 'Feature' as const,
          properties: {
            id: inter.id,
            name: inter.name,
          },
          geometry: {
            type: 'Point' as const,
            coordinates: coords,
          },
        }
      }),
    }
  }

  const buildIncidentsGeoJSON = () => {
    const list = incidents || []
    return {
      type: 'FeatureCollection' as const,
      features: list.flatMap((inc) => {
        const coords = inc.lon != null && inc.lat != null
          ? [Number(inc.lon), Number(inc.lat)] as [number, number]
          : undefined
        if (!coords) return []
        return {
          type: 'Feature' as const,
          properties: {
            id: inc.id,
            type: inc.type,
            severity: inc.severity,
            description: inc.description || '',
          },
          geometry: {
            type: 'Point' as const,
            coordinates: coords,
          },
        }
      }),
    }
  }

  const buildRoutesGeoJSON = (coordMap: Map<number, [number, number]>) => {
    const roadCoords = new Map<number, [number, number][]>()
    ;(roads || []).forEach((road) => {
      const fromCoord = coordMap.get(road.from_intersection_id)
      const toCoord = coordMap.get(road.to_intersection_id)
      if (road.geometry?.coordinates?.length >= 2) {
        roadCoords.set(road.road_segment_id, road.geometry.coordinates)
      } else if (fromCoord && toCoord) {
        roadCoords.set(road.road_segment_id, [fromCoord, toCoord])
      }

    })

    const list = routes || []
    return {
      type: 'FeatureCollection' as const,
      features: list.flatMap((route) => {
        const coordinates: [number, number][] = []
        ;(route.segments || []).forEach((segment: { road_segment_id: number }) => {
          const segmentCoords = roadCoords.get(segment.road_segment_id)
          if (!segmentCoords) return
          const from = segmentCoords[0]
          if (coordinates.length === 0) coordinates.push(from)
          else if (coordinates[coordinates.length - 1][0] !== from[0] || coordinates[coordinates.length - 1][1] !== from[1]) coordinates.push(from)
          coordinates.push(...segmentCoords.slice(1))
        })
        if (coordinates.length < 2) return []
        return {
          type: 'Feature' as const,
          properties: {
            id: route.id,
            status: route.status,
            total_time: route.total_time_min,
          },
          geometry: {
            type: 'LineString' as const,
            coordinates,
          },
        }

      }),
    }
  }

  const buildLiveRouteGeoJSON = () => ({
    type: 'FeatureCollection' as const,
    features: liveRoute?.geometry
      ? [{
          type: 'Feature' as const,
          properties: { source: liveRoute.source },
          geometry: liveRoute.geometry,
        }]
      : [],
  })

  // 1. Initialize Map instance once on mount
  useEffect(() => {
    if (!mapContainer.current) return

    const m = new maplibregl.Map({
      container: mapContainer.current,
      style: OPEN_STREET_MAP_STYLE,
      center: [77.5946, 12.9716],
      zoom: 11.4,
      attributionControl: true
    })

    m.addControl(new maplibregl.NavigationControl(), 'top-right')

    m.on('load', () => {
      isLoaded.current = true

      // Initialize empty sources
      m.addSource('roads', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } })
      m.addSource('intersections', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } })
      m.addSource('incidents', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } })
      m.addSource('routes', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } })
      m.addSource('live-route', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } })

      // Road Layer
      m.addLayer({
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
          'line-width': 3.5,
          'line-opacity': 0.85,
        },
      })

      // Intersections Layer
      m.addLayer({
        id: 'intersections-layer',
        type: 'circle',
        source: 'intersections',
        paint: {
          'circle-radius': 5,
          'circle-color': '#2563eb',
          'circle-stroke-width': 1.5,
          'circle-stroke-color': '#ffffff',
        },
      })

      // Incidents Layer
      m.addLayer({
        id: 'incidents-layer',
        type: 'circle',
        source: 'incidents',
        paint: {
          'circle-radius': 9,
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

      // Routes Layer
      m.addLayer({
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
          'line-width': 4.5,
          'line-dasharray': [2, 1],
        },
      })
      m.addLayer({
        id: 'live-route-layer',
        type: 'line',
        source: 'live-route',
        paint: {
          'line-color': '#7c3aed',
          'line-width': 6,
          'line-opacity': 0.95,
        },
      })

      // Populate data right after layer setup
      const coordMap = getCoordMap()
      ;(m.getSource('roads') as maplibregl.GeoJSONSource)?.setData(buildRoadsGeoJSON(coordMap))
      ;(m.getSource('intersections') as maplibregl.GeoJSONSource)?.setData(buildIntersectionsGeoJSON(coordMap))
      ;(m.getSource('incidents') as maplibregl.GeoJSONSource)?.setData(buildIncidentsGeoJSON())
      ;(m.getSource('routes') as maplibregl.GeoJSONSource)?.setData(buildRoutesGeoJSON(coordMap))
      ;(m.getSource('live-route') as maplibregl.GeoJSONSource)?.setData(buildLiveRouteGeoJSON())
    })

    map.current = m

    return () => {
      isLoaded.current = false
      m.remove()
      map.current = null
    }
  }, [])

  // 2. Seamlessly update data sources when props change (NO MAP RE-CREATION)
  useEffect(() => {
    if (!map.current || !isLoaded.current) return

    const coordMap = getCoordMap()
    const m = map.current

    const roadsSrc = m.getSource('roads') as maplibregl.GeoJSONSource
    if (roadsSrc) roadsSrc.setData(buildRoadsGeoJSON(coordMap))

    const interSrc = m.getSource('intersections') as maplibregl.GeoJSONSource
    if (interSrc) interSrc.setData(buildIntersectionsGeoJSON(coordMap))

    const incSrc = m.getSource('incidents') as maplibregl.GeoJSONSource
    if (incSrc) incSrc.setData(buildIncidentsGeoJSON())

    const routesSrc = m.getSource('routes') as maplibregl.GeoJSONSource
    if (routesSrc) routesSrc.setData(buildRoutesGeoJSON(coordMap))
    const liveRouteSrc = m.getSource('live-route') as maplibregl.GeoJSONSource
    if (liveRouteSrc) liveRouteSrc.setData(buildLiveRouteGeoJSON())
  }, [roads, intersections, incidents, routes, liveRoute, vehicles])

  return (
    <div className="relative w-full h-[600px] rounded-lg overflow-hidden border border-gray-200 shadow-sm">
      <div ref={mapContainer} className="w-full h-full" />
    </div>
  )
}
