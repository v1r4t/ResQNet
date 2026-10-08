// frontend/src/api/incidents.ts
import api from './client'
import { Incident } from '../types/api'

export const submitIncidentReport = async (rawText: string) => {
  const response = await api.post('/incidents/report', { raw_text: rawText })
  return response.data
}

export const createManualIncident = async (data: any) => {
  const response = await api.post('/incidents/manual', data)
  return response.data
}

export const getIncidents = async (params?: { status?: string; severity?: string; zone_id?: number }) => {
  const response = await api.get('/incidents', { params })
  return response.data as Incident[]
}

export const clearIncident = async (id: number) => {
  const response = await api.post(`/incidents/${id}/clear`)
  return response.data
}
