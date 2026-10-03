// Port de components/ChatList.vue (coluna da lista): cabeçalho, abas, cards, scroll infinito, filtros avançados,
// pastas e o menu de contexto do card (ConversationItem.vue). Ações em massa ficam para a próxima fatia.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { MouseEvent, ReactNode } from 'react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import {
  customFilterKeys,
  customFiltersQuery,
  deleteCustomFilter,
  updateCustomFilter,
} from '../../api/custom-filters'
import {
  assignConversation,
  conversationKeys,
  deleteConversation,
  markSeen,
  markUnread,
  toggleStatus,
  togglePriority,
  updateConversationLabels,
} from '../../api/conversations'
import { inboxesQuery } from '../../api/inboxes'
import { labelsQuery } from '../../api/labels'
import { teamsQuery } from '../../api/teams'
import type { Conversation, ConversationPriority, ConversationStatus } from '../../api/types'
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
import { ContextMenu } from './context-menu/context-menu'
import { ConversationContextMenu } from './context-menu/conversation-context-menu'
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
  /** Caminho da conversa na visão atual (conversationUrl): abrir em nova aba e copiar o link. */
  conversationHref?: (conversation: Conversation) => string
  /** redirectToConversationList: fecha a conversa aberta mantendo a visão. */
  onCloseConversation?: () => void
}

export function ConversationList({
  search,
  activeId,
  onSearchChange,
  renderCardLink,
  expanded = false,
  onToggleLayout,
  conversationHref = (conversation) => `/app/conversations/${conversation.id}`,
  onCloseConversation,
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

  // Menu de contexto do card (ConversationItem.vue + os handlers do ChatList.vue)
  const [menu, setMenu] = useState<{ id: number; labels: string[]; x: number; y: number } | null>(
    null,
  )
  const [deleteId, setDeleteId] = useState<number | null>(null)
  const menuConversation = menu && conversations.find((c) => c.id === menu.id)
  const closeMenu = useCallback(() => setMenu(null), [])
  // useScrollLock do ContextMenu.vue: a lista não rola com o menu aberto
  const menuOpen = menu !== null
  useEffect(() => {
    const list = listRef.current
    if (!menuOpen || !list) return
    list.style.overflow = 'hidden'
    return () => {
      list.style.overflow = ''
    }
  }, [menuOpen])
  const openMenu = (conversation: Conversation, event: MouseEvent) => {
    event.preventDefault()
    setMenu({
      id: conversation.id,
      labels: conversation.labels,
      x: event.clientX,
      y: event.clientY,
    })
  }
  const refresh = () => queryClient.invalidateQueries({ queryKey: conversationKeys.all(accountId) })
  const fullUrl = (conversation: Conversation) =>
    `${window.location.origin}${conversationHref(conversation)}`

  const updateStatus = async (id: number, status: ConversationStatus) => {
    closeMenu()
    await toggleStatus(accountId, id, { status })
    showAlert(t('CONVERSATION.CHANGE_STATUS'))
    void refresh()
  }
  const setPriority = async (id: number, priority: ConversationPriority) => {
    closeMenu()
    await togglePriority(accountId, id, priority)
    // o ChatList.vue interpola a chave crua da prioridade
    showAlert(
      t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
        priority: priority ?? '',
        conversationId: id,
      }),
    )
    void refresh()
  }
  const assignAgent = async (id: number, agent: { id: number | null; name: string }) => {
    closeMenu()
    try {
      await assignConversation(accountId, id, { assignee_id: agent.id })
      showAlert(
        t('CONVERSATION.CARD_CONTEXT_MENU.API.AGENT_ASSIGNMENT.SUCCESFUL', {
          agentName: agent.name,
          conversationId: id,
        }),
      )
      void refresh()
    } catch {
      showAlert(t('CONVERSATION.CARD_CONTEXT_MENU.API.AGENT_ASSIGNMENT.FAILED'))
    }
  }
  const assignTeam = async (id: number, team: { id: number; name: string }) => {
    closeMenu()
    try {
      await assignConversation(accountId, id, { team_id: team.id })
      showAlert(
        t('CONVERSATION.CARD_CONTEXT_MENU.API.TEAM_ASSIGNMENT.SUCCESFUL', {
          team: team.name,
          conversationId: id,
        }),
      )
      void refresh()
    } catch {
      showAlert(t('CONVERSATION.CARD_CONTEXT_MENU.API.TEAM_ASSIGNMENT.FAILED'))
    }
  }
  // O Chatwoot usa o bulk_actions (add/remove); sem ele aqui, manda a lista inteira. O menu continua aberto.
  const changeLabels = async (id: number, title: string, add: boolean) => {
    const current = menu?.labels ?? []
    const next = add ? [...current, title] : current.filter((l) => l !== title)
    const scope = add ? 'LABEL_ASSIGNMENT' : 'LABEL_REMOVAL'
    try {
      const saved = await updateConversationLabels(accountId, id, next)
      setMenu((m) => (m?.id === id ? { ...m, labels: saved } : m))
      showAlert(
        t(`CONVERSATION.CARD_CONTEXT_MENU.API.${scope}.SUCCESFUL`, {
          labelName: title,
          conversationId: id,
        }),
      )
      void refresh()
    } catch {
      showAlert(t(`CONVERSATION.CARD_CONTEXT_MENU.API.${scope}.FAILED`))
    }
  }
  const confirmDelete = async () => {
    const id = deleteId
    setDeleteId(null)
    if (id === null) return
    try {
      await deleteConversation(accountId, id)
      // a conversa aberta não pode ser rebuscada (404): sai do cache antes de atualizar as listas
      queryClient.removeQueries({ queryKey: conversationKeys.detail(accountId, id) })
      queryClient.removeQueries({ queryKey: conversationKeys.messages(accountId, id) })
      onCloseConversation?.()
      showAlert(t('CONVERSATION.SUCCESS_DELETE_CONVERSATION'))
      void queryClient.invalidateQueries({ queryKey: [...conversationKeys.all(accountId), 'list'] })
      void queryClient.invalidateQueries({
        queryKey: [...conversationKeys.all(accountId), 'filtered'],
      })
    } catch {
      showAlert(t('CONVERSATION.FAIL_DELETE_CONVERSATION'))
    }
  }

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
              onContextMenu: (event: MouseEvent) => openMenu(conversation, event),
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

      {menu && menuConversation && (
        <ContextMenu x={menu.x} y={menu.y} onClose={closeMenu}>
          <ConversationContextMenu
            status={menuConversation.status}
            hasUnreadMessages={menuConversation.unread_count > 0}
            inboxId={menuConversation.inbox_id}
            priority={menuConversation.priority}
            conversationLabels={menu.labels}
            onUpdateConversation={(status) => void updateStatus(menu.id, status)}
            onMarkAsUnread={() => {
              closeMenu()
              void markUnread(accountId, menu.id)
                .then(() => {
                  onCloseConversation?.()
                  return refresh()
                })
                .catch(() => {})
            }}
            onMarkAsRead={() => {
              closeMenu()
              void markSeen(accountId, menu.id)
                .then(refresh)
                .catch(() => {})
            }}
            onAssignPriority={(priority) => void setPriority(menu.id, priority)}
            onAssignAgent={(agent) => void assignAgent(menu.id, agent)}
            onAssignTeam={(team) => void assignTeam(menu.id, team)}
            onAssignLabel={(label) => void changeLabels(menu.id, label.title, true)}
            onRemoveLabel={(label) => void changeLabels(menu.id, label.title, false)}
            onOpenInNewTab={() => {
              window.open(fullUrl(menuConversation), '_blank', 'noopener,noreferrer')
              closeMenu()
            }}
            onCopyLink={() => {
              void navigator.clipboard
                .writeText(fullUrl(menuConversation))
                .then(() => {
                  showAlert(t('CONVERSATION.CARD_CONTEXT_MENU.COPY_LINK_SUCCESS'))
                  closeMenu()
                })
                .catch(() => {})
            }}
            onDeleteConversation={() => {
              setDeleteId(menu.id)
              closeMenu()
            }}
          />
        </ContextMenu>
      )}
      <Dialog
        open={deleteId !== null}
        type="alert"
        title={t('CONVERSATION.DELETE_CONVERSATION.TITLE', { conversationId: deleteId })}
        description={t('CONVERSATION.DELETE_CONVERSATION.DESCRIPTION')}
        confirmLabel={t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')}
        cancelLabel={t('DIALOG.BUTTONS.CANCEL')}
        onClose={() => setDeleteId(null)}
        onConfirm={() => void confirmDelete()}
      />
    </section>
  )
}
