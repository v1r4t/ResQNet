// frontend/src/pages/NetworkExplorer.tsx
import { useQuery } from '@tanstack/react-query'
import { getNetworkState } from '../api/network'

export default function NetworkExplorer() {
  const { data: network } = useQuery({ queryKey: ['network'], queryFn: getNetworkState })

  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">Network Explorer</h2>
      <table className="w-full bg-white rounded shadow">
        <thead>
          <tr className="border-b">
            <th className="p-2 text-left">Road</th>
            <th className="p-2 text-left">From</th>
            <th className="p-2 text-left">To</th>
            <th className="p-2 text-left">Travel Time</th>
            <th className="p-2 text-left">Congestion</th>
          </tr>
        </thead>
        <tbody>
          {network?.roads.map((road) => (
            <tr key={road.road_segment_id} className="border-b">
              <td className="p-2">{road.road_name}</td>
              <td className="p-2">{road.from_intersection_id}</td>
              <td className="p-2">{road.to_intersection_id}</td>
              <td className="p-2">{road.travel_time_min.toFixed(1)} min</td>
              <td className="p-2">{road.congestion_level}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
