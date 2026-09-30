import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { Availability, Profile } from './types'

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

// ---- Perfil: endpoints de api/v1/profiles_controller.rb ----

export const updateUiSettings = (uiSettings: Record<string, unknown>) =>
  api.put<Profile>('/api/v1/profile', { profile: { ui_settings: uiSettings } })

export const setAvailability = (accountId: number, availability: Availability) =>
  api.post<Profile>('/api/v1/profile/availability', {
    profile: { account_id: accountId, availability },
  })

export const setAutoOffline = (accountId: number, autoOffline: boolean) =>
  api.post<Profile>('/api/v1/profile/auto_offline', {
    profile: { account_id: accountId, auto_offline: autoOffline },
  })

export const setActiveAccount = (accountId: number) =>
  api.put<null>('/api/v1/profile/set_active_account', { profile: { account_id: accountId } })
