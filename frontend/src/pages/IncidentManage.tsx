// frontend/src/pages/IncidentManage.tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { getIncidents, clearIncident } from '../api/incidents'

export default function IncidentManage() {
  const queryClient = useQueryClient()
  const { data: incidents } = useQuery({ queryKey: ['incidents'], queryFn: () => getIncidents() })

  const clearMutation = useMutation({
    mutationFn: clearIncident,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['incidents'] })
  })

  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">Manage Incidents</h2>
      <table className="w-full bg-white rounded shadow">
        <thead>
          <tr className="border-b">
            <th className="p-2 text-left">ID</th>
            <th className="p-2 text-left">Type</th>
            <th className="p-2 text-left">Severity</th>
            <th className="p-2 text-left">Status</th>
            <th className="p-2 text-left">Actions</th>
          </tr>
        </thead>
        <tbody>
          {incidents?.map((incident) => (
            <tr key={incident.id} className="border-b">
              <td className="p-2">{incident.id}</td>
              <td className="p-2">{incident.type}</td>
              <td className="p-2">{incident.severity}</td>
              <td className="p-2">{incident.status}</td>
              <td className="p-2">
                {incident.status === 'active' && (
                  <button onClick={() => clearMutation.mutate(incident.id)} className="bg-red-500 text-white px-2 py-1 rounded text-sm">
                    Clear
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
