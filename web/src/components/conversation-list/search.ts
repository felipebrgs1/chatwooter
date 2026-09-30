// Filtros da lista vivem na URL (search params de /app): é assim que a sidebar filtra
// (ex.: /app?team_id=2, /app?conversation_type=mention). Params inválidos são ignorados.
import type { ConversationFilters } from '../../api/conversations'
import type { ConversationStatus } from '../../api/types'

export const STATUSES = ['open', 'resolved', 'pending', 'snoozed', 'all'] as const
export const ASSIGNEE_TABS = ['me', 'unassigned', 'all'] as const
export const SORTS = [
  'last_activity_at_asc',
  'last_activity_at_desc',
  'created_at_desc',
  'created_at_asc',
  'unread',
  'priority_desc',
  'priority_asc',
  'priority_desc_created_at_asc',
  'waiting_since_asc',
  'waiting_since_desc',
] as const
export const CONVERSATION_TYPES = ['mention', 'participating', 'unattended'] as const

export interface ConversationsSearch {
  status: (typeof STATUSES)[number]
  assignee_type: (typeof ASSIGNEE_TABS)[number]
  sort_by: (typeof SORTS)[number]
  inbox_id?: number
  team_id?: number
  label?: string
  conversation_type?: (typeof CONVERSATION_TYPES)[number]
}

const oneOf = <T extends string>(list: readonly T[], value: unknown): T | undefined =>
  typeof value === 'string' && (list as readonly string[]).includes(value)
    ? (value as T)
    : undefined

function positiveInt(value: unknown): number | undefined {
  const n = typeof value === 'number' ? value : typeof value === 'string' ? Number(value) : NaN
  return Number.isInteger(n) && n > 0 ? n : undefined
}

/** Só o que a URL traz de válido, sem padrões: mantém as URLs curtas (`/app`) e o tipo da rota opcional. */
export function parseUrlSearch(raw: Record<string, unknown>): Partial<ConversationsSearch> {
  const search: Partial<ConversationsSearch> = {}
  const status = oneOf(STATUSES, raw.status)
  const assignee = oneOf(ASSIGNEE_TABS, raw.assignee_type)
  const sort = oneOf(SORTS, raw.sort_by)
  const inbox = positiveInt(raw.inbox_id)
  const team = positiveInt(raw.team_id)
  const type = oneOf(CONVERSATION_TYPES, raw.conversation_type)
  if (status) search.status = status
  if (assignee) search.assignee_type = assignee
  if (sort) search.sort_by = sort
  if (inbox) search.inbox_id = inbox
  if (team) search.team_id = team
  if (typeof raw.label === 'string' && raw.label !== '') search.label = raw.label
  if (type) search.conversation_type = type
  return search
}

export function withDefaults(search: Partial<ConversationsSearch>): ConversationsSearch {
  return { status: 'open', assignee_type: 'me', sort_by: 'last_activity_at_desc', ...search }
}

export const parseSearch = (raw: Record<string, unknown>) => withDefaults(parseUrlSearch(raw))

export function toFilters(search: ConversationsSearch): ConversationFilters {
  const { label, status, ...rest } = search
  return {
    ...rest,
    status: status as ConversationStatus | 'all',
    ...(label ? { labels: [label] } : {}),
  }
}

/** Título da lista na precedência do pageTitle de ChatList.vue (inbox/time dependem de endpoints que ainda não existem). */
export function viewTitle(search: ConversationsSearch): { key: string } | { text: string } {
  if (search.label) return { text: `#${search.label}` }
  switch (search.conversation_type) {
    case 'mention':
      return { key: 'CHAT_LIST.MENTION_HEADING' }
    case 'unattended':
      return { key: 'CHAT_LIST.UNATTENDED_HEADING' }
    case 'participating':
      return { key: 'SIDEBAR.PARTICIPATING_CONVERSATIONS' }
    default:
      return { key: 'CHAT_LIST.TAB_HEADING' }
  }
}
