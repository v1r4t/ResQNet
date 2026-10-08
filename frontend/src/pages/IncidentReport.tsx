// frontend/src/pages/IncidentReport.tsx
import { useState } from 'react'
import { submitIncidentReport } from '../api/incidents'

export default function IncidentReport() {
  const [rawText, setRawText] = useState('')
  const [result, setResult] = useState<any>(null)
  const [loading, setLoading] = useState(false)
  const [mode, setMode] = useState<'report' | 'manual'>('report')

  const handleSubmit = async () => {
    setLoading(true)
    try {
      const data = await submitIncidentReport(rawText)
      setResult(data)
    } catch (error) {
      alert('Failed to submit report')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto space-y-4">
      <h2 className="text-2xl font-bold">Report Incident</h2>

      <div className="flex space-x-2">
        <button onClick={() => setMode('report')} className={`px-4 py-2 rounded ${mode === 'report' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}>
          Unstructured Report
        </button>
        <button onClick={() => setMode('manual')} className={`px-4 py-2 rounded ${mode === 'manual' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}>
          Manual Entry
        </button>
      </div>

      {mode === 'report' ? (
        <textarea
          value={rawText}
          onChange={(e) => setRawText(e.target.value)}
          placeholder="Describe the incident... e.g., 'Major accident on Outer Ring Road. Two lanes blocked.'"
          className="w-full h-32 p-4 border rounded"
        />
      ) : (
        <div className="space-y-2">
          <input placeholder="Type (accident, fire, construction)" className="w-full p-2 border rounded" />
          <input placeholder="Severity (low, medium, high, critical)" className="w-full p-2 border rounded" />
          <input placeholder="Road name" className="w-full p-2 border rounded" />
          <input placeholder="Lanes blocked" type="number" className="w-full p-2 border rounded" />
        </div>
      )}

      <button onClick={handleSubmit} disabled={loading} className="bg-blue-500 text-white px-6 py-2 rounded">
        {loading ? 'Processing...' : 'Submit'}
      </button>

      {result && (
        <div className="bg-white p-4 rounded shadow space-y-2">
          <h3 className="font-bold">Extraction Result</h3>
          <pre className="bg-gray-100 p-2 rounded text-sm">{JSON.stringify(result, null, 2)}</pre>
        </div>
      )}
    </div>
  )
}
