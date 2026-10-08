// frontend/src/api/routing.ts
import api from './client'
import { Route } from '../types/api'

export const requestRoute = async (data: { origin_id: number; destination_id: number; vehicle_id?: number; priority?: number }) => {
  const response = await api.post('/routes/request', data)
  return response.data as Route
}

export const recalculateRoutes = async () => {
  const response = await api.post('/routes/recalculate')
  return response.data
}
