import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { Profile } from './types'

// Uma consulta só para "quem sou eu": o guard das rotas e as telas leem o mesmo cache.
export const profileQuery = queryOptions({
  queryKey: ['profile'],
  queryFn: () => api.get<Profile>('/api/v1/profile'),
  retry: false,
  staleTime: 5 * 60 * 1000,
})

export async function signIn(email: string, password: string): Promise<Profile> {
  const response = await api.post<{ data: Profile }>('/auth/sign_in', { email, password })
  return response.data
}

export function signOut() {
  return api.delete<{ success: boolean }>('/auth/sign_out')
}
