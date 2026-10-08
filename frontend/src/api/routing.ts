// frontend/src/api/routing.ts
import api from './client'

export interface RouteResult {
  route_id: number
  request_id: number
  total_time_min: number
  total_distance_m: number
}

export const requestRoute = async (data: { origin_id: number; destination_id: number; vehicle_id?: number; priority?: number }) => {
  const response = await api.post('/routes/request', data)
  return response.data as RouteResult
}

export const recalculateRoutes = async () => {
  const response = await api.post('/routes/recalculate')
  return response.data
}
