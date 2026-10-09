// frontend/src/pages/Dashboard.tsx
import { useQuery } from '@tanstack/react-query'
import { getNetworkState } from '../api/client'
import { getIncidents } from '../api/incidents'
import NetworkMap from '../components/map/NetworkMap'

export default function Dashboard() {
  const { data: network } = useQuery({ queryKey: ['network'], queryFn: getNetworkState, refetchInterval: 10000 })
  const { data: incidents } = useQuery({ queryKey: ['incidents'], queryFn: () => getIncidents({ status: 'active' }), refetchInterval: 10000 })
  const activeRoutes = network?.routes || []
  const roadCount = network?.roads.length || 0
  const congestedRoads = (network?.roads || []).filter((road) => ['heavy', 'blocked'].includes(road.congestion_level)).length

  return (
    <div className="dashboard-page">
      <div className="dashboard-heading">
        <div>
          <h1 className="page-title">Dispatch overview</h1>
          <p className="page-lead">Monitor emergency routes, incidents, and city network health.</p>
        </div>
        <div className="dashboard-actions"><button className="toolbar-button">⌕ Search</button><button className="toolbar-button">◌ Export</button><div className="live-badge"><span className="status-dot" /> live</div></div>
      </div>
      <div className="dispatch-grid">
        <div className="map-shell dispatch-map">
          <div className="map-header">
            <div><span className="map-title">Live city network</span><span className="map-subtitle">Bengaluru, Karnataka</span></div>
            <div className="map-tools"><span>⌗</span><span>＋</span><span>−</span></div>
          </div>
          <NetworkMap
            roads={network?.roads || []}
            intersections={network?.intersections || []}
            incidents={incidents || []}
            routes={network?.routes || []}
          />
        </div>
        <aside className="dashboard-side">
          <section className="reference-card">
            <div className="card-heading"><h2>Network performance</h2><span className="more-button">···</span></div>
            <div className="performance-bars">
              <div><span>Clear</span><b className="bar-label">58%</b><i className="performance-bar clear-bar" /></div>
              <div><span>Moderate</span><b className="bar-label">24%</b><i className="performance-bar moderate-bar" /></div>
              <div><span>Heavy</span><b className="bar-label">{roadCount ? Math.round((congestedRoads / roadCount) * 100) : 0}%</b><i className="performance-bar heavy-bar" /></div>
              <div><span>Blocked</span><b className="bar-label">{incidents?.length || 0}</b><i className="performance-bar blocked-bar" /></div>
            </div>
            <div className="card-footnote"><span>Roads monitored</span><strong>{roadCount}</strong></div>
          </section>
          <section className="reference-card">
            <div className="card-heading"><h2>Response snapshot</h2><span className="card-arrow">↗</span></div>
            <div className="snapshot-number">95<span>%</span></div>
            <p className="snapshot-copy">network capacity currently available</p>
            <div className="mini-chart"><i /><i /><i /><i /><i /><i /><i /><i /><i /><i /><i /><i /><i /><i /><i /><i /></div>
            <div className="snapshot-footer"><span><b>{activeRoutes.length}</b> active routes</span><span><b>{incidents?.length || 0}</b> incidents</span></div>
          </section>
          <section className="priority-card">
            <div><p>Need assistance?</p><strong>Report a city incident</strong></div>
            <a href="/incidents/report">＋</a>
          </section>
        </aside>
      </div>
      <section className="orders-card">
        <div className="orders-heading"><div><h2>Active response routes</h2><p>Live routes currently managed by ResQNet</p></div><div className="table-tabs"><span className="tab-active">All</span><span>Active</span><span>Stale</span><button>⌕</button></div></div>
        <div className="route-table">
          <div className="route-row route-header"><span>Route ID</span><span>Network status</span><span>Segments</span><span>ETA</span><span>Action</span></div>
          {activeRoutes.length > 0 ? activeRoutes.slice(0, 5).map((route) => (
            <div className="route-row" key={route.id}><span className="route-id">↗ RQ{route.id}</span><span><i className={`status-pill ${route.status}`}>{route.status}</i></span><span>{route.segments?.length || 0} segments</span><span>{route.total_time_min?.toFixed(1) || '--'} min</span><span className="row-action">View route&nbsp; →</span></div>
          )) : (
            <div className="empty-routes">No active database routes. Use Route command to plot a live Bengaluru corridor.</div>
          )}
        </div>
      </section>
      <p className="data-note">Bengaluru basemap shown for reference. The current database network is a synthetic simulation and is not an actual Bangalore road network.</p>
    </div>
  )
}
