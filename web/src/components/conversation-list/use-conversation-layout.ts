import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback } from 'react'

import { profileQuery, updateUiSettings } from '../../api/auth'
import type { Profile } from '../../api/types'

const isExpanded = (settings: Record<string, unknown> | undefined) =>
  (settings?.conversation_display_type ?? 'condensed') !== 'condensed'

// useUISettings.js → isOnExpandedLayout: tudo que não é "condensed" (o padrão) é expandido.
// O Dashboard.vue ainda força o expandido em telas pequenas gravando ui_settings a cada resize;
// aqui o mobile já alterna lista/conversa pela largura, então isso não foi portado.
export function useConversationLayout() {
  const queryClient = useQueryClient()
  const { data: profile } = useQuery(profileQuery)

  // ChatListHeader.vue → toggleConversationLayout (grava também o último layout escolhido).
  // Lê o perfil do cache na hora: o PUT substitui ui_settings inteiro.
  const toggle = useCallback(async () => {
    const previous = queryClient.getQueryData<Profile>(profileQuery.queryKey)
    const next = isExpanded(previous?.ui_settings) ? 'condensed' : 'expanded'
    const merged = {
      ...previous?.ui_settings,
      conversation_display_type: next,
      previously_used_conversation_display_type: next,
    }
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
  }, [queryClient])

  return { expanded: isExpanded(profile?.ui_settings), toggle }
}
