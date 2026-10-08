// frontend/src/api/network.ts
import api from './client'
import { NetworkState } from '../types/api'

export const getNetworkState = async (): Promise<NetworkState> => {
  const response = await api.get('/network/state')
  return response.data
}
