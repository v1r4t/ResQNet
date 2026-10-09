// frontend/src/pages/RoutePlanner.tsx
import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { getLiveRoute } from '../api/live'
import NetworkMap from '../components/map/NetworkMap'

const BANGALORE_LOCATIONS = {
  'Majestic': [77.5726, 12.9767],
  'Vidhana Soudha': [77.5923, 12.9796],
  'Indiranagar': [77.6412, 12.9784],
  'Koramangala': [77.6245, 12.9352],
  'Electronic City': [77.6727, 12.8452],
  'Whitefield': [77.7500, 12.9698],
  'Hebbal': [77.5946, 13.0358],
  'Yeshwanthpur': [77.5400, 13.0285],
  'Kempegowda Airport': [77.7066, 13.1986],
} as const

type LocationName = keyof typeof BANGALORE_LOCATIONS

interface RouteResult {
  distance_m: number
  duration_min: number
  source: string
}

export default function RoutePlanner() {
  const [origin, setOrigin] = useState<LocationName>('Majestic')
  const [destination, setDestination] = useState<LocationName>('Kempegowda Airport')
  const [result, setResult] = useState<RouteResult | null>(null)
  const [error, setError] = useState<string | null>(null)

  const routeMutation = useMutation({
    mutationFn: () => getLiveRoute(
      [...BANGALORE_LOCATIONS[origin]] as [number, number],
      [...BANGALORE_LOCATIONS[destination]] as [number, number],
    ),
    onSuccess: (data) => {
      setResult(data)
      setError(null)
    },
    onError: (err: any) => {
      setError(err?.response?.data?.detail || 'Failed to calculate route')
    }
  })

  const handleCalculate = () => {
    if (origin === destination) {
      setError('Origin and destination must be different')
      return
    }
    setError(null)
    routeMutation.mutate()
  }

  return (
    <div className="space-y-4">
      <div className="dashboard-heading">
        <div><p className="section-kicker">OSRM live corridor planning</p><h1 className="page-title">Route command</h1><p className="page-lead">Plot the fastest response corridor between Bengaluru landmarks.</p></div>
        <div className="source-badge">OPENSTREETMAP / LIVE</div>
      </div>
      <div className="glass-panel route-controls">
        <div className="route-field"><label>Origin</label><select value={origin} onChange={(e) => setOrigin(e.target.value as LocationName)} className="field">{Object.keys(BANGALORE_LOCATIONS).map((name) => <option key={name}>{name}</option>)}</select></div>
        <div className="route-arrow">→</div>
        <div className="route-field"><label>Destination</label><select value={destination} onChange={(e) => setDestination(e.target.value as LocationName)} className="field">{Object.keys(BANGALORE_LOCATIONS).map((name) => <option key={name}>{name}</option>)}</select></div>
        <button
          onClick={handleCalculate}
          disabled={routeMutation.isPending}
          className="button-primary route-submit"
        >
          {routeMutation.isPending ? 'Calculating...' : 'Calculate route'}
        </button>
      </div>
      {error && <div className="alert-error">{error}</div>}
      <div className="map-shell planner-map"><NetworkMap roads={[]} intersections={[]} liveRoute={routeMutation.data} /></div>
      {result && (
        <div className="glass-panel route-result">
          <div><p className="section-kicker">Corridor locked</p><p className="route-result-title">{origin} <span>→</span> {destination}</p></div>
          <div className="route-metrics"><div><span>ETA</span><strong>{result.duration_min.toFixed(1)}<small> min</small></strong></div><div><span>Distance</span><strong>{(result.distance_m / 1000).toFixed(1)}<small> km</small></strong></div><div><span>Geometry</span><strong className="source-value">{result.source}</strong></div></div>
        </div>
      )}
    </div>
  )
}
