import { Routes, Route, Link, useLocation } from 'react-router-dom'
import Dashboard from './pages/Dashboard'
import IncidentReport from './pages/IncidentReport'
import IncidentManage from './pages/IncidentManage'
import RoutePlanner from './pages/RoutePlanner'
import Analytics from './pages/Analytics'
import NetworkExplorer from './pages/NetworkExplorer'
import DatabaseAnalytics from './pages/DatabaseAnalytics'

const NAV_ITEMS = [
  { to: '/', label: 'Overview', icon: '⌂' },
  { to: '/routes', label: 'Route command', icon: '↗' },
  { to: '/incidents/report', label: 'Report incident', icon: '＋' },
  { to: '/incidents', label: 'Incidents', icon: '!' },
  { to: '/analytics', label: 'Analytics', icon: '⌁' },
  { to: '/network', label: 'Network', icon: '◈' },
]

function App() {
  const location = useLocation()
  const activeItem = NAV_ITEMS.find((item) => item.to === location.pathname)

  return (
    <div className="app-shell">
      <div className="ambient ambient-cyan" />
      <div className="ambient ambient-violet" />
      <nav className="topbar">
        <div className="brand-lockup">
          <div className="brand-mark">R<span>Q</span></div>
          <div>
            <div className="brand-name">ResQNet</div>
            <div className="brand-subtitle">Emergency operations</div>
          </div>
        </div>
        <div className="nav-links">
          {NAV_ITEMS.map((item) => (
            <Link key={item.to} to={item.to} className={`nav-link ${location.pathname === item.to ? 'nav-link-active' : ''}`}>
              {item.label}
            </Link>
          ))}
        </div>
        <div className="system-status">
          <span className="status-dot" />
          <span>Network live</span>
        </div>
      </nav>
      <main className="app-content">
        <div className="page-context">
          <span>Workspace</span>
          <span className="context-divider">/</span>
          <span>{activeItem?.label || 'Command view'}</span>
        </div>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/incidents/report" element={<IncidentReport />} />
          <Route path="/incidents" element={<IncidentManage />} />
          <Route path="/routes" element={<RoutePlanner />} />
          <Route path="/analytics" element={<Analytics />} />
          <Route path="/network" element={<NetworkExplorer />} />
          <Route path="/db-analytics" element={<DatabaseAnalytics />} />
        </Routes>
      </main>
      <footer className="app-footer">
        <span>RESQNET OS 1.0</span>
        <span>Live routing intelligence for emergency response</span>
        <span className="footer-pulse"><span className="status-dot" /> systems nominal</span>
      </footer>
    </div>
  )
}

export default App
