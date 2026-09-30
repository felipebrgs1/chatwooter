// Port de components/ChatList.vue (coluna da lista): cabeçalho, abas, cards, scroll infinito, filtros avançados
// e pastas. Menu de contexto e ações em massa ficam para as próximas fatias.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import {
  customFilterKeys,
  customFiltersQuery,
  deleteCustomFilter,
  updateCustomFilter,
} from '../../api/custom-filters'
import { inboxesQuery } from '../../api/inboxes'
import { labelsQuery } from '../../api/labels'
import { teamsQuery } from '../../api/teams'
import type { Conversation } from '../../api/types'
import { useAccountId } from '../../api/use-account-id'
import { useMediaQuery } from '../layout/use-media-query'
import { cx } from '../next/cx'
import { Dialog } from '../next/dialog'
import { ConversationFilter } from '../next/filter/conversation-filter'
import {
  generatePayload,
  initialFiltersFromView,
  rowFromCondition,
  type FilterRow,
} from '../next/filter/filter-query'
import { SaveCustomView } from '../next/filter/save-custom-view'
import { useConversationFilterTypes } from '../next/filter/use-conversation-filter-types'
import { showAlert } from '../toast/alert'
import { toFilters, viewTitle, type ConversationsSearch } from './search'
import { ChatListHeader } from './chat-list-header'
import { ChatTypeTabs } from './chat-type-tabs'
import { ConversationCard, type CardLinkProps } from './conversation-card'
import { ConversationCardExpanded } from './conversation-card-expanded'
import { useConversations, useFilteredConversations } from './use-conversations'
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
  const accountId = useAccountId()
  const queryClient = useQueryClient()
  const { data: folders, isPending: foldersPending } = useQuery(customFiltersQuery(accountId))
  const activeFolder = search.folder_id
    ? folders?.find((f) => f.id === search.folder_id)
    : undefined
  const hasAppliedFilters = !!search.filters
  const hasActiveFolder = !hasAppliedFilters && !!activeFolder
  const filteredPayload = hasAppliedFilters ? search.filters : activeFolder?.query.payload
  // pasta na URL que não existe (excluída, de outro usuário): volta para a lista, como o isFolderAvailable
  useEffect(() => {
    if (search.folder_id && !hasAppliedFilters && !foldersPending && !activeFolder)
      onSearchChange({ folder_id: undefined })
  }, [search.folder_id, hasAppliedFilters, foldersPending, activeFolder, onSearchChange])
  const filteredView = hasAppliedFilters || !!search.folder_id
  const listQuery = useConversations(toFilters(search), { enabled: !filteredView })
  const filteredQuery = useFilteredConversations(
    filteredView ? filteredPayload : undefined,
    search.sort_by,
  )
  const query = filteredView ? filteredQuery : listQuery
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
    // a lista da aba anterior (placeholder) só segura os contadores; os cards esperam a aba nova
    if (query.isPlaceholderData) return []
    const seen = new Set<number>()
    const pages = filteredView
      ? (filteredQuery.data?.pages ?? []).map((page) => page.payload)
      : (listQuery.data?.pages ?? []).map((page) => page.data.payload)
    return pages.flat().filter((c) => !seen.has(c.id) && seen.add(c.id))
  }, [filteredView, filteredQuery.data, listQuery.data, query.isPlaceholderData])

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
    folder: activeFolder?.name,
  })
  const title = 'key' in heading ? t(heading.key) : heading.text
  const counts = listQuery.data?.pages[0]?.data.meta
  const filteredCount = filteredQuery.data?.pages[0]?.meta.all_count ?? 0

  // Modais do cabeçalho (onToggleAdvanceFiltersModal, SaveCustomView, DeleteCustomViews)
  const { lists } = useConversationFilterTypes()
  const [modalFilters, setModalFilters] = useState<FilterRow[] | null>(null)
  const [showSaveFolder, setShowSaveFolder] = useState(false)
  const [showDeleteFolder, setShowDeleteFolder] = useState(false)
  const closeFilters = useCallback(() => setModalFilters(null), [])
  const closeSaveFolder = useCallback(() => setShowSaveFolder(false), [])

  const openFilters = () => {
    if (modalFilters) return closeFilters()
    const saved = hasAppliedFilters
      ? search.filters
      : hasActiveFolder
        ? activeFolder?.query.payload
        : undefined
    setModalFilters(
      saved
        ? saved.map((condition) => rowFromCondition(condition, lists))
        : initialFiltersFromView(search, {
            statusName: t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${search.status}.TEXT`),
            inbox: inboxes.find((i) => i.id === search.inbox_id),
            team: teams.find((tm) => tm.id === search.team_id),
          }),
    )
  }

  const updateFolder = useMutation({
    mutationFn: ({ rows, name }: { rows: FilterRow[]; name: string }) =>
      updateCustomFilter(accountId, activeFolder!.id, {
        name,
        query: { payload: generatePayload(rows) },
      }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: customFilterKeys.all(accountId) }),
  })

  const openFolder = (id: number) =>
    onSearchChange({
      folder_id: id,
      filters: undefined,
      inbox_id: undefined,
      team_id: undefined,
      label: undefined,
      conversation_type: undefined,
    })

  const deleteFolder = useMutation({
    mutationFn: () => deleteCustomFilter(accountId, activeFolder!.id),
    onSuccess: async () => {
      showAlert(t('FILTER.CUSTOM_VIEWS.DELETE.API_FOLDERS.SUCCESS_MESSAGE'))
      await queryClient.invalidateQueries({ queryKey: customFilterKeys.all(accountId) })
      // openLastItemAfterDelete: a última pasta que sobrou, ou a lista
      const remaining = queryClient.getQueryData(customFiltersQuery(accountId).queryKey) ?? []
      const last = remaining.at(-1)
      if (last) openFolder(last.id)
      else onSearchChange({ folder_id: undefined })
    },
    onError: () => showAlert(t('FILTER.CUSTOM_VIEWS.DELETE.API_FOLDERS.ERROR_MESSAGE')),
  })

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
        hasAppliedFilters={hasAppliedFilters}
        hasActiveFolder={hasActiveFolder}
        allCount={filteredCount}
        isListLoading={query.isPending && !conversations.length}
        onResetFilters={() => onSearchChange({ filters: undefined })}
        onOpenFilters={openFilters}
        onAddFolder={() => setShowSaveFolder(true)}
        onDeleteFolder={() => setShowDeleteFolder(true)}
        filterPanel={
          modalFilters && (
            <ConversationFilter
              initialFilters={modalFilters}
              isFolderView={hasActiveFolder}
              folderName={activeFolder?.name}
              onClose={closeFilters}
              onApply={(rows) => {
                closeFilters()
                onSearchChange({ filters: generatePayload(rows), folder_id: undefined })
              }}
              onUpdateFolder={(rows, name) => {
                closeFilters()
                updateFolder.mutate({ rows, name })
              }}
            />
          )
        }
        savePanel={
          showSaveFolder &&
          search.filters && (
            <SaveCustomView
              query={{ payload: search.filters }}
              onClose={closeSaveFolder}
              onSaved={(folder) => openFolder(folder.id)}
            />
          )
        }
      />
      {activeFolder && (
        <Dialog
          open={showDeleteFolder}
          type="alert"
          title={t('FILTER.CUSTOM_VIEWS.DELETE.MODAL.CONFIRM.TITLE')}
          description={`${t('FILTER.CUSTOM_VIEWS.DELETE.MODAL.CONFIRM.MESSAGE')} ${activeFolder.name}?`}
          confirmLabel={t('FILTER.CUSTOM_VIEWS.DELETE.MODAL.CONFIRM.YES')}
          cancelLabel={t('FILTER.CUSTOM_VIEWS.DELETE.MODAL.CONFIRM.NO')}
          onClose={() => setShowDeleteFolder(false)}
          onConfirm={() => {
            setShowDeleteFolder(false)
            deleteFolder.mutate()
          }}
        />
      )}
      {!filteredView && (
        <ChatTypeTabs
          active={search.assignee_type}
          counts={counts}
          onChange={(assignee_type) => onSearchChange({ assignee_type })}
        />
      )}

      <div ref={listRef} className="conversations-list min-h-0 flex-1 overflow-y-auto">
        {(query.isPending || query.isPlaceholderData) && (
          <p className="p-4 text-center text-n-slate-11">{t('CHAT_LIST.LOADING')}</p>
        )}
        {query.isError && (
          <p role="alert" className="p-4 text-center text-n-slate-11">
            {t('CHAT_LIST.FETCH_ERROR')}
          </p>
        )}
        {query.isSuccess && !query.isPlaceholderData && conversations.length === 0 && (
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
                showAssignee={filteredView || search.assignee_type === 'all'}
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
