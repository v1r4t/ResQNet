// frontend/src/pages/Analytics.tsx
import { useQuery } from '@tanstack/react-query'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, PieChart, Pie, Cell } from 'recharts'
import { getCongestion, getIncidentFrequency, getRoutePerformance, getResponseTimes } from '../api/analytics'

export default function Analytics() {
  const { data: congestion } = useQuery({ queryKey: ['congestion'], queryFn: getCongestion })
  const { data: frequency } = useQuery({ queryKey: ['frequency'], queryFn: getIncidentFrequency })
  useQuery({ queryKey: ['performance'], queryFn: getRoutePerformance })
  useQuery({ queryKey: ['responseTimes'], queryFn: getResponseTimes })

  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">Analytics</h2>
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white p-4 rounded shadow">
          <h3 className="font-bold mb-2">Congestion Hotspots</h3>
          <BarChart width={400} height={200} data={congestion || []}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="zone_name" />
            <YAxis />
            <Tooltip />
            <Bar dataKey="avg_travel_time" fill="#ef4444" />
          </BarChart>
        </div>
        <div className="bg-white p-4 rounded shadow">
          <h3 className="font-bold mb-2">Incident Frequency</h3>
          <PieChart width={400} height={200}>
            <Pie data={frequency || []} dataKey="incident_count" nameKey="incident_type" cx={200} cy={100} outerRadius={80} label>
              {(frequency || []).map((_: any, i: number) => <Cell key={i} fill={['#ef4444', '#f59e0b', '#3b82f6', '#10b981'][i % 4]} />)}
            </Pie>
            <Tooltip />
          </PieChart>
        </div>
      </div>
    </div>
  )
}
