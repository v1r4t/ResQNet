import api from './client'

export interface LiveRoute {
  source: string
  distance_m: number
  duration_s: number
  duration_min: number
  geometry: {
    type: 'LineString'
    coordinates: [number, number][]
  }
  steps: Array<{
    name: string
    distance_m: number
    duration_s: number
    type: string | null
  }>
}

export const getLiveRoute = async (
  origin: [number, number],
  destination: [number, number],
) => {
  const response = await api.get('/live/route', {
    params: {
      origin_lon: origin[0],
      origin_lat: origin[1],
      destination_lon: destination[0],
      destination_lat: destination[1],
    },
  })
  return response.data as LiveRoute
}
