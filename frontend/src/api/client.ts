// frontend/src/api/client.ts
import axios from 'axios'
import { NetworkState } from '../types/api'

const api = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' }
})

export const getNetworkState = async (): Promise<NetworkState> => {
  const response = await api.get('/network/state')
  return response.data
}

export default api
