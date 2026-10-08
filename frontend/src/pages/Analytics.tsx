// frontend/src/pages/Analytics.tsx
import { useQuery } from '@tanstack/react-query'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, PieChart, Pie, Cell, ScatterChart, Scatter, LineChart, Line, Legend } from 'recharts'
import { getCongestion, getIncidentFrequency, getRoutePerformance, getResponseTimes } from '../api/analytics'

export default function Analytics() {
  const { data: congestion, isLoading: congestionLoading, error: congestionError } = useQuery({
    queryKey: ['congestion'],
    queryFn: getCongestion,
    refetchInterval: 10000
  })
  const { data: frequency, isLoading: frequencyLoading, error: frequencyError } = useQuery({
    queryKey: ['frequency'],
    queryFn: getIncidentFrequency,
    refetchInterval: 10000
  })
  const { data: routePerf, isLoading: routePerfLoading, error: routePerfError } = useQuery({
    queryKey: ['routePerformance'],
    queryFn: getRoutePerformance,
    refetchInterval: 10000
  })
  const { data: responseTimes, isLoading: responseTimesLoading, error: responseTimesError } = useQuery({
    queryKey: ['responseTimes'],
    queryFn: getResponseTimes,
    refetchInterval: 10000
  })

  if (congestionLoading || frequencyLoading || routePerfLoading || responseTimesLoading) return <div className="p-4">Loading analytics...</div>
  if (congestionError || frequencyError || routePerfError || responseTimesError) return <div className="p-4 text-red-500">Failed to load analytics</div>

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
        <div className="bg-white p-4 rounded shadow">
          <h3 className="font-bold mb-2">Route Performance</h3>
          <ScatterChart width={400} height={200}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="estimated_time" name="Estimated Time" unit=" min" />
            <YAxis dataKey="actual_time_min" name="Actual Time" unit=" min" />
            <Tooltip cursor={{ strokeDasharray: '3 3' }} />
            <Scatter name="Routes" data={routePerf || []} fill="#3b82f6" />
          </ScatterChart>
        </div>
        <div className="bg-white p-4 rounded shadow">
          <h3 className="font-bold mb-2">Response Times</h3>
          <LineChart width={400} height={200} data={responseTimes || []}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="hour" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Line type="monotone" dataKey="avg_estimated_time" stroke="#ef4444" name="Avg Estimated Time" />
            <Line type="monotone" dataKey="request_count" stroke="#3b82f6" name="Request Count" yAxisId={0} />
          </LineChart>
        </div>
      </div>
    </div>
  )
}
