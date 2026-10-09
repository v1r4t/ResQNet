// frontend/src/components/ui/StatCard.tsx
interface StatCardProps {
  title: string
  value: string | number
  color?: string
  detail?: string
}

export default function StatCard({ title, value, color = 'blue', detail }: StatCardProps) {
  return (
    <div className={`stat-card stat-${color}`}>
      <div className="stat-card-top">
        <p>{title}</p>
        <span className="stat-signal" />
      </div>
      <p className="stat-value">{value}</p>
      {detail && <p className="stat-detail">{detail}</p>}
    </div>
  )
}
