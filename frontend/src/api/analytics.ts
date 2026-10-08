// frontend/src/api/analytics.ts
import api from './client'

export const getCongestion = async () => {
  const response = await api.get('/analytics/congestion')
  return response.data
}

export const getIncidentFrequency = async () => {
  const response = await api.get('/analytics/incident-frequency')
  return response.data
}

export const getRoutePerformance = async () => {
  const response = await api.get('/analytics/route-performance')
  return response.data
}

export const getResponseTimes = async () => {
  const response = await api.get('/analytics/response-times')
  return response.data
}

export const getExplainPlan = async (queryId: string) => {
  const response = await api.get(`/analytics/explain/${queryId}`)
  return response.data
}
