// frontend/src/components/ui/StatCard.tsx
interface StatCardProps {
  title: string
  value: string | number
  color?: string
}

export default function StatCard({ title, value, color = 'blue' }: StatCardProps) {
  return (
    <div className={`bg-white rounded-lg shadow p-4 border-l-4 border-${color}-500`}>
      <p className="text-gray-500 text-sm">{title}</p>
      <p className="text-2xl font-bold">{value}</p>
    </div>
  )
}
