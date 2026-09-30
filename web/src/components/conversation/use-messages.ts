// Mensagens da conversa: paginação para trás (`before`) e envio otimista com `echo_id`.
import {
  useInfiniteQuery,
  useQuery,
  useQueryClient,
  type InfiniteData,
} from '@tanstack/react-query'
import { useCallback, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { profileQuery } from '../../api/auth'
import { ApiError } from '../../api/client'
import { conversationKeys, fetchMessages, sendMessage } from '../../api/conversations'
import type { Conversation, Message, MessagesResponse } from '../../api/types'
import type { ThreadMessage } from './message-variant'

/** O Chatwoot entrega 20 mensagens por página; menos que isso é o começo da conversa. */
export const PAGE_SIZE = 20

type Pages = InfiniteData<MessagesResponse, number | undefined>

export function useMessages(accountId: number, conversation: Conversation) {
  const queryClient = useQueryClient()
  const { t } = useTranslation()
  const { data: profile } = useQuery(profileQuery)
  const key = conversationKeys.messages(accountId, conversation.id)
  const [pending, setPending] = useState<ThreadMessage[]>([])
  const sequence = useRef(0)

  const query = useInfiniteQuery({
    queryKey: key,
    queryFn: ({ pageParam }) => fetchMessages(accountId, conversation.id, pageParam),
    initialPageParam: undefined as number | undefined,
    // A próxima página é a anterior à mais antiga já carregada (páginas vêm em ordem crescente de id)
    getNextPageParam: (last) => (last.payload.length >= PAGE_SIZE ? last.payload[0].id : undefined),
  })

  const server = useMemo<ThreadMessage[]>(() => {
    const seen = new Set<number>()
    return [...(query.data?.pages ?? [])]
      .reverse()
      .flatMap((p) => p.payload)
      .filter((m) => (seen.has(m.id) ? false : (seen.add(m.id), true)))
  }, [query.data])

  const dispatch = useCallback(
    async (content: string, isPrivate: boolean, echoId: string) => {
      const draft: ThreadMessage = {
        id: -(Date.now() * 1000 + ++sequence.current),
        content,
        inbox_id: conversation.inbox_id,
        echo_id: echoId,
        conversation_id: conversation.id,
        message_type: 1,
        content_type: 'text',
        status: 'progress',
        content_attributes: {},
        created_at: Math.floor(Date.now() / 1000),
        private: isPrivate,
        source_id: null,
        sender: profile ? { id: profile.id, name: profile.name, type: 'user' } : undefined,
      }
      setPending((list) => [...list.filter((m) => m.echo_id !== echoId), draft])
      try {
        const saved = await sendMessage(accountId, conversation.id, {
          content,
          private: isPrivate,
          echo_id: echoId,
        })
        queryClient.setQueryData<Pages>(key, (data) => appendMessage(data, saved))
        setPending((list) => list.filter((m) => m.echo_id !== echoId))
      } catch (error) {
        const reason = error instanceof ApiError ? error.message : t('CHAT_LIST.FAILED_TO_SEND')
        setPending((list) =>
          list.map((m) =>
            m.echo_id === echoId
              ? { ...m, status: 'failed', content_attributes: { external_error: reason } }
              : m,
          ),
        )
      }
    },
    [accountId, conversation, key, profile, queryClient, t],
  )

  const send = useCallback(
    (content: string, isPrivate: boolean) => dispatch(content, isPrivate, crypto.randomUUID()),
    [dispatch],
  )

  // Reenvio de uma pendente que falhou reaproveita o echo_id; de uma que o servidor marcou como falha, cria outra.
  const retry = useCallback(
    (message: ThreadMessage) =>
      dispatch(
        message.content ?? '',
        message.private,
        message.echo_id && message.id < 0 ? message.echo_id : crypto.randomUUID(),
      ),
    [dispatch],
  )

  return {
    messages: [...server, ...pending],
    isLoading: query.isPending,
    hasOlder: query.hasNextPage,
    isLoadingOlder: query.isFetchingNextPage,
    loadOlder: query.fetchNextPage,
    send,
    retry,
  }
}

function appendMessage(data: Pages | undefined, saved: Message): Pages | undefined {
  if (!data) return data
  if (data.pages.some((p) => p.payload.some((m) => m.id === saved.id))) return data
  const [newest, ...rest] = data.pages
  return { ...data, pages: [{ ...newest, payload: [...newest.payload, saved] }, ...rest] }
}
