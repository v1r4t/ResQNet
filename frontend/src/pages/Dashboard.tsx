// frontend/src/pages/Dashboard.tsx
import { useQuery } from '@tanstack/react-query'
import { getNetworkState } from '../api/client'
import { getIncidents } from '../api/incidents'
import NetworkMap from '../components/map/NetworkMap'
import StatCard from '../components/ui/StatCard'

export default function Dashboard() {
  const { data: network } = useQuery({ queryKey: ['network'], queryFn: getNetworkState, refetchInterval: 10000 })
  const { data: incidents } = useQuery({ queryKey: ['incidents'], queryFn: () => getIncidents({ status: 'active' }), refetchInterval: 10000 })

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-4 gap-4">
        <StatCard title="Active Incidents" value={incidents?.length || 0} color="red" />
        <StatCard title="Road Segments" value={network?.roads.length || 0} color="blue" />
        <StatCard title="Intersections" value={network?.intersections.length || 0} color="green" />
        <StatCard title="Network Health" value="95%" color="yellow" />
      </div>
      <NetworkMap
        roads={network?.roads || []}
        intersections={network?.intersections || []}
        incidents={incidents || []}
      />
    </div>
  )
}
