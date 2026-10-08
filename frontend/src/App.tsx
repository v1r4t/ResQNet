import { Routes, Route } from 'react-router-dom'
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
            <a href="/" className="hover:underline">Dashboard</a>
            <a href="/incidents/report" className="hover:underline">Report</a>
            <a href="/incidents" className="hover:underline">Incidents</a>
            <a href="/routes" className="hover:underline">Routes</a>
            <a href="/analytics" className="hover:underline">Analytics</a>
            <a href="/network" className="hover:underline">Network</a>
            <a href="/db-analytics" className="hover:underline">DB Analytics</a>
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
