// frontend/src/pages/DatabaseAnalytics.tsx
import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { getExplainPlan } from '../api/analytics'

const QUERIES = [
  { id: 'nearest_vehicle', name: 'Nearest Vehicle' },
  { id: 'congestion_hotspots', name: 'Congestion Hotspots' },
  { id: 'route_reconstruction', name: 'Route Reconstruction' },
  { id: 'incident_frequency', name: 'Incident Frequency' },
  { id: 'road_history', name: 'Road History' },
]

export default function DatabaseAnalytics() {
  const [selectedQuery, setSelectedQuery] = useState('')
  const { data: plan, isLoading, error } = useQuery({
    queryKey: ['explain', selectedQuery],
    queryFn: () => getExplainPlan(selectedQuery),
    enabled: !!selectedQuery,
    refetchInterval: 10000
  })

  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">Database Analytics</h2>
      <div className="flex space-x-2">
        {QUERIES.map((q) => (
          <button key={q.id} onClick={() => setSelectedQuery(q.id)} className={`px-4 py-2 rounded ${selectedQuery === q.id ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}>
            {q.name}
          </button>
        ))}
      </div>
      {selectedQuery && isLoading && <div className="p-4">Loading query plan...</div>}
      {error && <div className="p-4 text-red-500">Failed to load query plan</div>}
      {plan && (
        <div className="bg-white p-4 rounded shadow">
          <h3 className="font-bold mb-2">Query Plan</h3>
          <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
            {plan.plan?.join('\n')}
          </pre>
        </div>
      )}
    </div>
  )
}
