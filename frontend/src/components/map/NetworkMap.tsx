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

export default function NetworkMap({ roads: _roads, intersections: _intersections, incidents: _incidents, routes: _routes, vehicles: _vehicles }: NetworkMapProps) {
  const mapContainer = useRef<HTMLDivElement>(null)
  const map = useRef<maplibregl.Map | null>(null)

  useEffect(() => {
    if (!mapContainer.current) return

    map.current = new maplibregl.Map({
      container: mapContainer.current,
      style: 'https://demotiles.maplibre.org/style.json',
      center: [77.15, 13.0],
      zoom: 12
    })

    return () => { map.current?.remove() }
  }, [])

  return <div ref={mapContainer} className="w-full h-[600px] rounded-lg" />
}
