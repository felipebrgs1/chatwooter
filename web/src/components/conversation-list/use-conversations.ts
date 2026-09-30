import { keepPreviousData, useInfiniteQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'

import {
  conversationKeys,
  fetchConversations,
  filterConversations,
  type ConversationFilters,
} from '../../api/conversations'
import type { AssigneeType, FilterCondition } from '../../api/types'
import { useAccountId } from '../../api/use-account-id'

export const PAGE_SIZE = 25

const PREFETCH_STALE_TIME = 30_000

const ASSIGNEE_TABS: AssigneeType[] = ['me', 'unassigned', 'all']

function listOptions(accountId: number, filters: ConversationFilters) {
  return {
    queryKey: conversationKeys.list(accountId, filters),
    queryFn: ({ pageParam }: { pageParam: number }) =>
      fetchConversations(accountId, { ...filters, page: pageParam }),
    initialPageParam: 1,
    // página cheia: pode haver mais; página curta (ou vazia): acabou
    getNextPageParam: (last: Awaited<ReturnType<typeof fetchConversations>>, pages: unknown[]) =>
      last.data.payload.length >= PAGE_SIZE ? pages.length + 1 : undefined,
  }
}

/**
 * Lista paginada (25 por página); trocar os filtros recomeça da página 1.
 * O Chatwoot guarda as três abas (Mine/Unassigned/All) no mesmo store e troca entre elas sem recarregar:
 * aqui a 1ª página das abas vizinhas é pré-carregada, e os contadores (iguais para as três) ficam na tela
 * enquanto uma aba ainda não carregada busca a sua (`isPlaceholderData`).
 */
export function useConversations(filters: ConversationFilters, { enabled = true } = {}) {
  const accountId = useAccountId()
  const queryClient = useQueryClient()
  const query = useInfiniteQuery({
    ...listOptions(accountId, filters),
    placeholderData: keepPreviousData,
    enabled,
  })

  const loaded = query.isSuccess && !query.isPlaceholderData
  useEffect(() => {
    if (!loaded) return
    for (const assignee_type of ASSIGNEE_TABS) {
      if (assignee_type === filters.assignee_type) continue
      // filters chega como objeto novo a cada render: com staleTime, repetir a pré-carga não refaz o pedido
      void queryClient.prefetchInfiniteQuery({
        ...listOptions(accountId, { ...filters, assignee_type }),
        staleTime: PREFETCH_STALE_TIME,
      })
    }
  }, [loaded, accountId, filters, queryClient])

  return query
}

/**
 * Lista de uma pasta ou de filtros avançados (POST /conversations/filter): mesma paginação, sem abas.
 * `payload` indefinido (pasta ainda carregando) deixa a busca parada.
 */
export function useFilteredConversations(payload: FilterCondition[] | undefined, sortBy?: string) {
  const accountId = useAccountId()
  return useInfiniteQuery({
    queryKey: conversationKeys.filtered(accountId, payload ?? [], sortBy),
    queryFn: ({ pageParam }) =>
      filterConversations(accountId, payload ?? [], { page: pageParam, sortBy }),
    initialPageParam: 1,
    enabled: !!payload,
    getNextPageParam: (last, pages) =>
      last.payload.length >= PAGE_SIZE ? pages.length + 1 : undefined,
  })
}
