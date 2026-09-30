// Port de components/ChatList.vue (coluna da lista): cabeçalho, abas, cards e scroll infinito.
// Layout expandido, filtros avançados, pastas, menu de contexto e ações em massa ficam para as próximas fatias.
import type { ReactNode } from 'react'
import { useEffect, useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'

import type { Conversation } from '../../api/types'
import { toFilters, viewTitle, type ConversationsSearch } from './search'
import { ChatListHeader } from './chat-list-header'
import { ChatTypeTabs } from './chat-type-tabs'
import { ConversationCard, type CardLinkProps } from './conversation-card'
import { useConversations } from './use-conversations'
import { useNow } from './use-now'

type Props = {
  search: ConversationsSearch
  /** Conversa aberta (a da URL). */
  activeId?: number
  onSearchChange: (patch: Partial<ConversationsSearch>) => void
  /** O pai injeta o <Link> do roteador, que leva à conversa mantendo os filtros. */
  renderCardLink?: (conversation: Conversation, props: CardLinkProps) => ReactNode
}

export function ConversationList({ search, activeId, onSearchChange, renderCardLink }: Props) {
  const { t } = useTranslation()
  const now = useNow()
  const query = useConversations(toFilters(search))
  const sentinel = useRef<HTMLDivElement>(null)

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

  const heading = viewTitle(search)
  const title = 'key' in heading ? t(heading.key) : heading.text
  const counts = query.data?.pages[0]?.data.meta

  return (
    <section className="relative flex w-full flex-shrink-0 flex-col border-r border-n-weak bg-n-surface-1 sm:w-[340px] 2xl:w-[412px]">
      <ChatListHeader
        title={title}
        status={search.status}
        sortBy={search.sort_by}
        onStatusChange={(status) => onSearchChange({ status })}
        onSortChange={(sort_by) => onSearchChange({ sort_by })}
      />
      <ChatTypeTabs
        active={search.assignee_type}
        counts={counts}
        onChange={(assignee_type) => onSearchChange({ assignee_type })}
      />

      <div className="conversations-list min-h-0 flex-1 overflow-y-auto">
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
          {conversations.map((conversation) => (
            <ConversationCard
              key={conversation.id}
              conversation={conversation}
              href={`/app/conversations/${conversation.id}`}
              active={conversation.id === activeId}
              showAssignee={search.assignee_type === 'all'}
              now={now}
              renderLink={renderCardLink && ((props) => renderCardLink(conversation, props))}
            />
          ))}
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
