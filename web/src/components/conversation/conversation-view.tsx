// Porta de components/widgets/conversation/ConversationBox.vue: cabeçalho + thread da conversa aberta.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'

import { ApiError } from '../../api/client'
import {
  conversationKeys,
  conversationQuery,
  markSeen,
  toggleStatus,
} from '../../api/conversations'
import type { Conversation, ConversationStatus } from '../../api/types'
import { useAccountId } from '../../api/use-account-id'
import { showAlert } from '../toast/alert'
import { ConversationHeader } from './conversation-header'
import { MessagesView } from './messages-view'

export function ConversationView({ conversationId }: { conversationId: number }) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const queryClient = useQueryClient()
  const { data: conversation, error } = useQuery(conversationQuery(accountId, conversationId))

  // Abrir a conversa zera o "não lida" do agente
  useEffect(() => {
    markSeen(accountId, conversationId).catch(() => {})
  }, [accountId, conversationId])

  const status = useMutation({
    mutationFn: (next: ConversationStatus) =>
      toggleStatus(accountId, conversationId, { status: next }),
    onSuccess: ({ payload }) => {
      queryClient.setQueryData<Conversation>(
        conversationKeys.detail(accountId, conversationId),
        (c) => c && { ...c, status: payload.current_status, snoozed_until: payload.snoozed_until },
      )
      void queryClient.invalidateQueries({ queryKey: [...conversationKeys.all(accountId), 'list'] })
      showAlert(t('CONVERSATION.CHANGE_STATUS'))
    },
    onError: () => showAlert(t('CONVERSATION.CHANGE_STATUS_FAILED')),
  })

  if (error instanceof ApiError && error.status === 404) {
    return <Message text={t('CONVERSATION.404')} />
  }
  if (!conversation) return <Message text={t('CONVERSATION.LOADING_CONVERSATIONS')} />

  return (
    <div className="conversation-details-wrap relative flex h-full w-full min-w-0 flex-col border-l border-n-weak bg-n-surface-1">
      <ConversationHeader
        conversation={conversation}
        statusLoading={status.isPending}
        onStatusChange={(next) => status.mutate(next)}
      />
      <div className="m-0 flex h-full min-h-0">
        <MessagesView key={conversation.id} conversation={conversation} />
      </div>
    </div>
  )
}

function Message({ text }: { text: string }) {
  return (
    <div className="flex h-full w-full flex-1 items-center justify-center bg-n-surface-1 text-n-slate-11">
      <p className="text-sm">{text}</p>
    </div>
  )
}
