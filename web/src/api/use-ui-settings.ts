// useUISettings.js: lê ui_settings do perfil e grava mesclando com o que está no cache na hora (o PUT
// substitui ui_settings inteiro). Otimista: a tela muda antes da resposta e volta se a gravação falhar.
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback } from 'react'

import { profileQuery, updateUiSettings } from './auth'
import type { Profile } from './types'

export function useUiSettings() {
  const queryClient = useQueryClient()
  const { data: profile } = useQuery(profileQuery)

  const update = useCallback(
    async (patch: Record<string, unknown>) => {
      const previous = queryClient.getQueryData<Profile>(profileQuery.queryKey)
      const merged = { ...previous?.ui_settings, ...patch }
      queryClient.setQueryData<Profile>(
        profileQuery.queryKey,
        (p) => p && { ...p, ui_settings: merged },
      )
      try {
        const saved = await updateUiSettings(merged)
        if (saved) queryClient.setQueryData(profileQuery.queryKey, saved)
      } catch {
        queryClient.setQueryData(profileQuery.queryKey, previous)
      }
    },
    [queryClient],
  )

  return { uiSettings: profile?.ui_settings ?? {}, update }
}
