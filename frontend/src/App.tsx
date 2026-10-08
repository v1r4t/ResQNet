import { Routes, Route, Link } from 'react-router-dom'
import Dashboard from './pages/Dashboard'
import IncidentReport from './pages/IncidentReport'
import IncidentManage from './pages/IncidentManage'
import RoutePlanner from './pages/RoutePlanner'
import Analytics from './pages/Analytics'
import NetworkExplorer from './pages/NetworkExplorer'
import DatabaseAnalytics from './pages/DatabaseAnalytics'

function App() {
  return (
    <div className="min-h-screen bg-gray-100">
      <nav className="bg-blue-900 text-white p-4">
        <div className="container mx-auto flex justify-between items-center">
          <h1 className="text-xl font-bold">ResQNet</h1>
          <div className="space-x-4">
            <Link to="/" className="hover:underline">Dashboard</Link>
            <Link to="/incidents/report" className="hover:underline">Report</Link>
            <Link to="/incidents" className="hover:underline">Incidents</Link>
            <Link to="/routes" className="hover:underline">Routes</Link>
            <Link to="/analytics" className="hover:underline">Analytics</Link>
            <Link to="/network" className="hover:underline">Network</Link>
            <Link to="/db-analytics" className="hover:underline">DB Analytics</Link>
          </div>
        </div>
      </nav>
      <main className="container mx-auto p-4">
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
    </div>
  )
}

export default App
