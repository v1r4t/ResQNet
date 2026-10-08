// frontend/src/pages/IncidentReport.tsx
import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { submitIncidentReport, createManualIncident } from '../api/incidents'

interface ManualFormData {
  type: string
  severity: string
  road: string
  lanes_blocked: number | ''
  description: string
}

const emptyManualForm: ManualFormData = {
  type: '',
  severity: '',
  road: '',
  lanes_blocked: '',
  description: '',
}

export default function IncidentReport() {
  const [rawText, setRawText] = useState('')
  const [mode, setMode] = useState<'report' | 'manual'>('report')
  const [manualForm, setManualForm] = useState<ManualFormData>(emptyManualForm)

  const reportMutation = useMutation({
    mutationFn: (text: string) => submitIncidentReport(text),
  })

  const manualMutation = useMutation({
    mutationFn: (data: ManualFormData) => createManualIncident({
      type: data.type,
      severity: data.severity,
      road: data.road,
      lanes_blocked: data.lanes_blocked === '' ? 0 : Number(data.lanes_blocked),
      description: data.description,
    }),
  })

  const result = reportMutation.data || manualMutation.data
  const loading = reportMutation.isPending || manualMutation.isPending

  const handleSubmit = () => {
    if (mode === 'report') {
      if (!rawText.trim()) return
      reportMutation.mutate(rawText)
    } else {
      manualMutation.mutate(manualForm)
    }
  }

  const updateManualField = (field: keyof ManualFormData, value: string) => {
    setManualForm(prev => ({
      ...prev,
      [field]: field === 'lanes_blocked' ? (value === '' ? '' : Number(value)) : value,
    }))
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
          <input
            placeholder="Type (accident, fire, construction)"
            value={manualForm.type}
            onChange={(e) => updateManualField('type', e.target.value)}
            className="w-full p-2 border rounded"
          />
          <input
            placeholder="Severity (low, medium, high, critical)"
            value={manualForm.severity}
            onChange={(e) => updateManualField('severity', e.target.value)}
            className="w-full p-2 border rounded"
          />
          <input
            placeholder="Road name"
            value={manualForm.road}
            onChange={(e) => updateManualField('road', e.target.value)}
            className="w-full p-2 border rounded"
          />
          <input
            placeholder="Lanes blocked"
            type="number"
            value={manualForm.lanes_blocked}
            onChange={(e) => updateManualField('lanes_blocked', e.target.value)}
            className="w-full p-2 border rounded"
          />
          <input
            placeholder="Description"
            value={manualForm.description}
            onChange={(e) => updateManualField('description', e.target.value)}
            className="w-full p-2 border rounded"
          />
        </div>
      )}

      <button onClick={handleSubmit} disabled={loading} className="bg-blue-500 text-white px-6 py-2 rounded">
        {loading ? 'Processing...' : 'Submit'}
      </button>

      {(reportMutation.isError || manualMutation.isError) && (
        <div className="bg-red-50 border border-red-200 text-red-700 p-3 rounded">
          Failed to submit report
        </div>
      )}

      {result && (
        <div className="bg-white p-4 rounded shadow space-y-4">
          <h3 className="font-bold text-lg">Processing Pipeline</h3>

          {/* Step 1: Raw Text */}
          <div className="border-l-4 border-blue-500 pl-3">
            <div className="font-semibold text-blue-700">Step 1: Raw Text Submitted</div>
            <pre className="bg-gray-100 p-2 rounded text-sm mt-1 whitespace-pre-wrap">
              {mode === 'report' ? rawText : JSON.stringify({
                type: manualForm.type,
                severity: manualForm.severity,
                road: manualForm.road,
                lanes_blocked: manualForm.lanes_blocked,
                description: manualForm.description,
              }, null, 2)}
            </pre>
          </div>

          {/* Step 2: LLM Extraction */}
          {result.extracted_data && (
            <div className="border-l-4 border-green-500 pl-3">
              <div className="font-semibold text-green-700">Step 2: LLM Extraction</div>
              <div className="text-sm text-gray-600 mt-1">
                Source: {result.extraction_source || 'unknown'}
                {result.extraction_fallback && ' (fallback)'}
              </div>
              <pre className="bg-gray-100 p-2 rounded text-sm mt-1">
                {JSON.stringify(result.extracted_data, null, 2)}
              </pre>
            </div>
          )}

          {/* Step 3: DB Transaction */}
          {result.incident_id && (
            <div className="border-l-4 border-purple-500 pl-3">
              <div className="font-semibold text-purple-700">Step 3: DB Transaction</div>
              <div className="text-sm mt-1">
                <div>Incident ID: <span className="font-mono">{result.incident_id}</span></div>
                {result.report_id && <div>Report ID: <span className="font-mono">{result.report_id}</span></div>}
                {result.affected_roads && result.affected_roads.length > 0 && (
                  <div>Affected Roads: <span className="font-mono">{result.affected_roads.join(', ')}</span></div>
                )}
              </div>
            </div>
          )}

          {/* Step 4: Routes Stale */}
          {result.affected_roads && result.affected_roads.length > 0 && (
            <div className="border-l-4 border-orange-500 pl-3">
              <div className="font-semibold text-orange-700">Step 4: Routes Marked Stale</div>
              <div className="text-sm text-gray-600 mt-1">
                {result.affected_roads.length} road segment(s) affected. Recalculation queued for dependent routes.
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
