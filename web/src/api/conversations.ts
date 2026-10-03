// Endpoints de conversas, no formato e nos caminhos da API do Chatwoot.
import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type {
  AssigneeType,
  Conversation,
  ConversationList,
  ConversationPriority,
  ConversationStatus,
  FilterCondition,
  FilteredConversations,
  MessagesResponse,
  Message,
} from './types'

export interface ConversationFilters {
  status?: ConversationStatus | 'all'
  assignee_type?: AssigneeType
  inbox_id?: number
  team_id?: number
  labels?: string[]
  conversation_type?: 'mention' | 'participating' | 'unattended'
  sort_by?: string
  page?: number
}

const base = (accountId: number) => `/api/v1/accounts/${accountId}/conversations`

function toQuery(filters: ConversationFilters) {
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(filters)) {
    if (value === undefined || value === null || value === '') continue
    if (Array.isArray(value)) value.forEach((v) => params.append(`${key}[]`, v))
    else params.set(key, String(value))
  }
  const qs = params.toString()
  return qs ? `?${qs}` : ''
}

export const conversationKeys = {
  all: (accountId: number) => ['accounts', accountId, 'conversations'] as const,
  list: (accountId: number, filters: ConversationFilters) =>
    [...conversationKeys.all(accountId), 'list', filters] as const,
  filtered: (accountId: number, payload: FilterCondition[], sortBy?: string) =>
    [...conversationKeys.all(accountId), 'filtered', payload, sortBy] as const,
  detail: (accountId: number, id: number) =>
    [...conversationKeys.all(accountId), 'detail', id] as const,
  messages: (accountId: number, id: number) =>
    [...conversationKeys.all(accountId), 'messages', id] as const,
}

/** ConversationApi.filter: as condições no corpo; página e ordenação na query string. */
export const filterConversations = (
  accountId: number,
  payload: FilterCondition[],
  { page, sortBy }: { page: number; sortBy?: string },
) => {
  const params = new URLSearchParams({ page: String(page) })
  if (sortBy) params.set('sort_by', sortBy)
  return api.post<FilteredConversations>(`${base(accountId)}/filter?${params}`, { payload })
}

export const fetchConversations = (accountId: number, filters: ConversationFilters = {}) =>
  api.get<ConversationList>(`${base(accountId)}${toQuery(filters)}`)

export const conversationQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: conversationKeys.detail(accountId, id),
    queryFn: () => api.get<Conversation>(`${base(accountId)}/${id}`),
  })

export const fetchMessages = (accountId: number, id: number, before?: number) =>
  api.get<MessagesResponse>(`${base(accountId)}/${id}/messages${before ? `?before=${before}` : ''}`)

export const sendMessage = (
  accountId: number,
  id: number,
  body: { content: string; private?: boolean; echo_id?: string },
) => api.post<Message>(`${base(accountId)}/${id}/messages`, body)

export const toggleStatus = (
  accountId: number,
  id: number,
  body: { status: ConversationStatus; snoozed_until?: number },
) =>
  api.post<{
    meta: Record<string, never>
    payload: {
      success: boolean
      conversation_id: number
      current_status: ConversationStatus
      snoozed_until: string | null
    }
  }>(`${base(accountId)}/${id}/toggle_status`, body)

export const assignConversation = (
  accountId: number,
  id: number,
  body: { assignee_id?: number | null; team_id?: number | null },
) => api.post(`${base(accountId)}/${id}/assignments`, body)

/** conversations#toggle_priority: null limpa. */
export const togglePriority = (accountId: number, id: number, priority: ConversationPriority) =>
  api.post<void>(`${base(accountId)}/${id}/toggle_priority`, { priority })

export const conversationLabelsQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: [...conversationKeys.detail(accountId, id), 'labels'] as const,
    queryFn: () =>
      api.get<{ payload: string[] }>(`${base(accountId)}/${id}/labels`).then((r) => r.payload),
  })

/** conversations/labels#create substitui a lista inteira (update_labels). */
export const updateConversationLabels = (accountId: number, id: number, labels: string[]) =>
  api
    .post<{ payload: string[] }>(`${base(accountId)}/${id}/labels`, { labels })
    .then((r) => r.payload)

export const markSeen = (accountId: number, id: number) =>
  api.post(`${base(accountId)}/${id}/update_last_seen`)

export const markUnread = (accountId: number, id: number) =>
  api.post(`${base(accountId)}/${id}/unread`)

/** conversations#destroy (só administrador). */
export const deleteConversation = (accountId: number, id: number) =>
  api.delete<void>(`${base(accountId)}/${id}`)

export type BulkActionPayload = {
  ids: number[]
  fields?: { status?: ConversationStatus; assignee_id?: number | null; team_id?: number }
  labels?: { add?: string[]; remove?: string[] }
  snoozed_until?: number
}

/** bulk_actions#create para conversas (useBulkActions e o menu de contexto). */
export const bulkActions = (accountId: number, payload: BulkActionPayload) =>
  api.post<void>(`/api/v1/accounts/${accountId}/bulk_actions`, { type: 'Conversation', ...payload })
