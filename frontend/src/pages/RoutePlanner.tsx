// frontend/src/pages/RoutePlanner.tsx
import { useState } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import { requestRoute, recalculateRoutes } from '../api/routing'
import { getNetworkState } from '../api/network'

interface RouteResult {
  route_id: number
  request_id: number
  total_time_min: number
  total_distance_m: number
}

export default function RoutePlanner() {
  const [origin, setOrigin] = useState('')
  const [destination, setDestination] = useState('')
  const [result, setResult] = useState<RouteResult | null>(null)
  const [error, setError] = useState<string | null>(null)

  const { data: network, isLoading: networkLoading, error: networkError } = useQuery({
    queryKey: ['network'],
    queryFn: getNetworkState,
    refetchInterval: 10000
  })

  const routeMutation = useMutation({
    mutationFn: () => requestRoute({ origin_id: Number(origin), destination_id: Number(destination) }),
    onSuccess: (data) => {
      setResult(data)
      setError(null)
    },
    onError: (err: any) => {
      setError(err?.response?.data?.detail || 'Failed to calculate route')
    }
  })

  const recalculateMutation = useMutation({
    mutationFn: recalculateRoutes,
    onError: (err: any) => {
      setError(err?.response?.data?.detail || 'Failed to recalculate routes')
    }
  })

  const handleCalculate = () => {
    if (!origin || !destination) {
      setError('Please select both origin and destination')
      return
    }
    if (origin === destination) {
      setError('Origin and destination must be different')
      return
    }
    setError(null)
    routeMutation.mutate()
  }

  if (networkLoading) return <div className="p-4">Loading network data...</div>
  if (networkError) return <div className="p-4 text-red-500">Failed to load network data</div>

  return (
    <div className="max-w-2xl mx-auto space-y-4">
      <h2 className="text-2xl font-bold">Route Planner</h2>
      <div className="flex space-x-2">
        <select value={origin} onChange={(e) => setOrigin(e.target.value)} className="p-2 border rounded">
          <option value="">Origin</option>
          {network?.intersections.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}
        </select>
        <select value={destination} onChange={(e) => setDestination(e.target.value)} className="p-2 border rounded">
          <option value="">Destination</option>
          {network?.intersections.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}
        </select>
        <button
          onClick={handleCalculate}
          disabled={routeMutation.isPending}
          className="bg-blue-500 text-white px-4 py-2 rounded disabled:opacity-50"
        >
          {routeMutation.isPending ? 'Calculating...' : 'Calculate'}
        </button>
        <button
          onClick={() => recalculateMutation.mutate()}
          disabled={recalculateMutation.isPending}
          className="bg-yellow-500 text-white px-4 py-2 rounded disabled:opacity-50"
        >
          {recalculateMutation.isPending ? 'Recalculating...' : 'Recalculate All'}
        </button>
      </div>
      {error && <div className="bg-red-100 text-red-700 p-2 rounded">{error}</div>}
      {result && (
        <div className="bg-white p-4 rounded shadow">
          <p>Route ID: {result.route_id}</p>
          <p>ETA: {result.total_time_min.toFixed(1)} min</p>
          <p>Distance: {result.total_distance_m.toFixed(0)} m</p>
        </div>
      )}
    </div>
  )
}
