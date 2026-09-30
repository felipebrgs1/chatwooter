import { useInfiniteQuery } from '@tanstack/react-query'

import {
  conversationKeys,
  fetchConversations,
  type ConversationFilters,
} from '../../api/conversations'
import { useAccountId } from '../../api/use-account-id'

export const PAGE_SIZE = 25

/** Lista paginada (25 por página); trocar os filtros recomeça da página 1. */
export function useConversations(filters: ConversationFilters) {
  const accountId = useAccountId()

  return useInfiniteQuery({
    queryKey: conversationKeys.list(accountId, filters),
    queryFn: ({ pageParam }) => fetchConversations(accountId, { ...filters, page: pageParam }),
    initialPageParam: 1,
    // página cheia: pode haver mais; página curta (ou vazia): acabou
    getNextPageParam: (last, pages) =>
      last.data.payload.length >= PAGE_SIZE ? pages.length + 1 : undefined,
  })
}
