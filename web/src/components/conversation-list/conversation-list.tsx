// Port de components/ChatList.vue (coluna da lista): cabeçalho, abas, cards e scroll infinito.
// Filtros avançados, pastas, menu de contexto e ações em massa ficam para as próximas fatias.
import { useQuery } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { useEffect, useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'

import { inboxesQuery } from '../../api/inboxes'
import { labelsQuery } from '../../api/labels'
import { teamsQuery } from '../../api/teams'
import type { Conversation } from '../../api/types'
import { useAccountId } from '../../api/use-account-id'
import { useMediaQuery } from '../layout/use-media-query'
import { cx } from '../next/cx'
import { toFilters, viewTitle, type ConversationsSearch } from './search'
import { ChatListHeader } from './chat-list-header'
import { ChatTypeTabs } from './chat-type-tabs'
import { ConversationCard, type CardLinkProps } from './conversation-card'
import { ConversationCardExpanded } from './conversation-card-expanded'
import { useConversations } from './use-conversations'
import { useChatListKeyboardEvents } from './use-chat-list-keyboard-events'

// wootConstants.LARGE_SCREEN_BREAKPOINT (lg do Tailwind)
const BELOW_LG_QUERY = '(max-width: 1023px)'

type Props = {
  search: ConversationsSearch
  /** Conversa aberta (a da URL). */
  activeId?: number
  onSearchChange: (patch: Partial<ConversationsSearch>) => void
  /** O pai injeta o <Link> do roteador, que leva à conversa mantendo os filtros. */
  renderCardLink?: (conversation: Conversation, props: CardLinkProps) => ReactNode
  /** isOnExpandedLayout (ui_settings): a lista ocupa a página, em linhas. */
  expanded?: boolean
  onToggleLayout?: () => void
}

export function ConversationList({
  search,
  activeId,
  onSearchChange,
  renderCardLink,
  expanded = false,
  onToggleLayout,
}: Props) {
  const { t } = useTranslation()
  // ConversationList.vue → showExpandedCards: as linhas só a partir do breakpoint lg
  const belowLg = useMediaQuery(BELOW_LG_QUERY)
  const expandedCards = expanded && !belowLg
  const query = useConversations(toFilters(search))
  const accountId = useAccountId()
  const { data: accountLabels } = useQuery(labelsQuery(accountId))
  const { data: inboxes = [] } = useQuery(inboxesQuery(accountId))
  const { data: teams = [] } = useQuery(teamsQuery(accountId))
  // ConversationItem.vue → showInboxName: fora da visão de uma inbox, e só se a conta tiver mais de uma
  const showInboxName = !search.inbox_id && inboxes.length > 1
  const inboxName = (id: number) =>
    showInboxName ? inboxes.find((i) => i.id === id)?.name : undefined
  const sentinel = useRef<HTMLDivElement>(null)
  const listRef = useRef<HTMLDivElement>(null)
  useChatListKeyboardEvents(listRef)

  const conversations = useMemo(() => {
    const seen = new Set<number>()
    return (query.data?.pages ?? [])
      .flatMap((page) => page.data.payload)
      .filter((c) => !seen.has(c.id) && seen.add(c.id))
  }, [query.data])

  const { hasNextPage, isFetchingNextPage, fetchNextPage } = query
  useEffect(() => {
    const el = sentinel.current
    if (!el || typeof IntersectionObserver === 'undefined') return
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting) && hasNextPage && !isFetchingNextPage)
        void fetchNextPage()
    })
    observer.observe(el)
    return () => observer.disconnect()
  }, [hasNextPage, isFetchingNextPage, fetchNextPage, conversations.length])

  const heading = viewTitle(search, {
    inbox: inboxes.find((i) => i.id === search.inbox_id)?.name,
    team: teams.find((tm) => tm.id === search.team_id)?.name,
  })
  const title = 'key' in heading ? t(heading.key) : heading.text
  const counts = query.data?.pages[0]?.data.meta

  return (
    <section
      className={cx(
        'relative flex w-full flex-shrink-0 flex-col bg-n-surface-1',
        expanded ? 'basis-full' : 'border-r border-n-weak sm:w-[340px] 2xl:w-[412px]',
      )}
    >
      <ChatListHeader
        title={title}
        status={search.status}
        sortBy={search.sort_by}
        onStatusChange={(status) => onSearchChange({ status })}
        onSortChange={(sort_by) => onSearchChange({ sort_by })}
        expanded={expanded}
        onToggleLayout={onToggleLayout}
      />
      <ChatTypeTabs
        active={search.assignee_type}
        counts={counts}
        onChange={(assignee_type) => onSearchChange({ assignee_type })}
      />

      <div ref={listRef} className="conversations-list min-h-0 flex-1 overflow-y-auto">
        {query.isPending && (
          <p className="p-4 text-center text-n-slate-11">{t('CHAT_LIST.LOADING')}</p>
        )}
        {query.isError && (
          <p role="alert" className="p-4 text-center text-n-slate-11">
            {t('CHAT_LIST.FETCH_ERROR')}
          </p>
        )}
        {query.isSuccess && conversations.length === 0 && (
          <p className="flex items-center justify-center overflow-auto p-4">
            {t('CHAT_LIST.LIST.404')}
          </p>
        )}

        <div className="[&>a:has(+_a.active)]:!border-n-surface-1">
          {conversations.map((conversation) => {
            const common = {
              conversation,
              href: `/app/conversations/${conversation.id}`,
              active: conversation.id === activeId,
              accountLabels,
              inboxName: inboxName(conversation.inbox_id),
              renderLink:
                renderCardLink && ((props: CardLinkProps) => renderCardLink(conversation, props)),
            }
            return expandedCards ? (
              <ConversationCardExpanded key={conversation.id} {...common} />
            ) : (
              <ConversationCard
                key={conversation.id}
                {...common}
                showAssignee={search.assignee_type === 'all'}
              />
            )
          })}
        </div>

        {conversations.length > 0 && <div ref={sentinel} aria-hidden="true" className="h-px" />}
        {isFetchingNextPage && (
          <p className="p-4 text-center text-n-slate-11">{t('CHAT_LIST.LOADING')}</p>
        )}
        {query.isSuccess && conversations.length > 0 && !hasNextPage && (
          <p className="p-4 text-center text-n-slate-11">{t('CHAT_LIST.EOF')}</p>
        )}
      </div>
    </section>
  )
}
