// frontend/src/pages/RoutePlanner.tsx
import { useState } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import { requestRoute, recalculateRoutes } from '../api/routing'
import { getNetworkState } from '../api/network'

export default function RoutePlanner() {
  const [origin, setOrigin] = useState('')
  const [destination, setDestination] = useState('')
  const [result, setResult] = useState<any>(null)

  const { data: network } = useQuery({ queryKey: ['network'], queryFn: getNetworkState })

  const routeMutation = useMutation({
    mutationFn: () => requestRoute({ origin_id: Number(origin), destination_id: Number(destination) }),
    onSuccess: (data) => setResult(data)
  })

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
        <button onClick={() => routeMutation.mutate()} className="bg-blue-500 text-white px-4 py-2 rounded">
          Calculate
        </button>
        <button onClick={() => recalculateRoutes()} className="bg-yellow-500 text-white px-4 py-2 rounded">
          Recalculate All
        </button>
      </div>
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
