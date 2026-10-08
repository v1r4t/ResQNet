// frontend/src/api/vehicles.ts
import api from './client'
import { Vehicle } from '../types/api'

export const getVehicles = async (params?: { vehicle_type?: string; status?: string; zone_id?: number }) => {
  const response = await api.get('/vehicles', { params })
  return response.data as Vehicle[]
}

export const getVehicleStatus = async () => {
  const response = await api.get('/vehicles/status')
  return response.data
}
