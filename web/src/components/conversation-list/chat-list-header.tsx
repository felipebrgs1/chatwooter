// Port de components/ChatListHeader.vue + ConversationBasicFilter.vue (status e ordenação) + SwitchLayout.vue.
// O filtro de contato (contactFilter, vindo do painel do contato) entra com o painel.
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '../next/button'
import { cx } from '../next/cx'
import { DropdownContainer } from '../next/dropdown-container'
import { SORTS, STATUSES, type ConversationsSearch } from './search'
import { FILTER_TOGGLE_ID } from '../next/filter/conversation-filter'
import { SAVE_FILTER_TOGGLE_ID } from '../next/filter/save-custom-view'
import { SelectMenu } from '../next/select-menu'

type Props = {
  title: string
  status: ConversationsSearch['status']
  sortBy: ConversationsSearch['sort_by']
  onStatusChange: (status: ConversationsSearch['status']) => void
  onSortChange: (sortBy: ConversationsSearch['sort_by']) => void
  /** isOnExpandedLayout: os menus abrem alinhados à direita. */
  expanded?: boolean
  onToggleLayout?: () => void
  hasAppliedFilters?: boolean
  hasActiveFolder?: boolean
  /** Total do conjunto filtrado (meta.all_count), mostrado no lugar do status. */
  allCount?: number
  isListLoading?: boolean
  onResetFilters?: () => void
  onOpenFilters?: () => void
  onAddFolder?: () => void
  onDeleteFolder?: () => void
  /** Modal de filtros (ou de editar pasta), aberto sob o botão que o chamou. */
  filterPanel?: ReactNode
  /** Formulário de salvar pasta, aberto sob o botão de salvar. */
  savePanel?: ReactNode
}

// formatNumber do @chatwoot/utils: 1.2K, 3M...
const formatCount = (n: number) =>
  new Intl.NumberFormat('en', { notation: 'compact', maximumFractionDigits: 1 }).format(n)

export function ChatListHeader({
  title,
  status,
  sortBy,
  onStatusChange,
  onSortChange,
  expanded = false,
  onToggleLayout,
  hasAppliedFilters = false,
  hasActiveFolder = false,
  allCount = 0,
  isListLoading = false,
  onResetFilters,
  onOpenFilters,
  onAddFolder,
  onDeleteFolder,
  filterPanel,
  savePanel,
}: Props) {
  const { t } = useTranslation()
  const filteredView = hasAppliedFilters || hasActiveFolder
  // com filtros (não pasta) o título ganha o botão de voltar
  const showFilterScope = hasAppliedFilters && !hasActiveFolder
  const panelSide = expanded ? 'right-0' : undefined

  const statusOptions = STATUSES.map((value) => ({
    value,
    label: t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${value}.TEXT`),
  }))
  const sortOptions = SORTS.map((value) => ({
    value,
    label: t(`CHAT_LIST.SORT_ORDER_ITEMS.${value}.TEXT`),
  }))
  const sortLabel = t('CHAT_LIST.SORT_TOOLTIP_LABEL')
  const switchLabel = t('CONVERSATION.SWITCH_VIEW_LAYOUT')
  const subMenuPosition = expanded ? 'left' : 'right'

  return (
    <div
      className={cx(
        'flex h-[3.25rem] items-center justify-between gap-2 px-3',
        filteredView && 'border-b border-n-strong',
      )}
    >
      <div className="flex min-w-0 items-center justify-center">
        {showFilterScope && (
          <Button
            icon="ph-caret-left"
            color="slate"
            variant="ghost"
            size="sm"
            title={t('FILTER.CLEAR_BUTTON_LABEL')}
            aria-label={t('FILTER.CLEAR_BUTTON_LABEL')}
            className="shrink-0 -ms-2 !h-6 !w-6 me-1"
            onClick={onResetFilters}
          />
        )}
        <h1 className="truncate text-base font-medium text-n-slate-12" title={title}>
          {title}
        </h1>
        {allCount > 0 && filteredView && !isListLoading && (
          <span
            className="mx-1 my-0.5 shrink-0 rounded-md bg-n-slate-3 px-2 py-1 text-xxs capitalize text-n-slate-12"
            title={String(allCount)}
          >
            {formatCount(allCount)}
          </span>
        )}
        {!filteredView && (
          <span
            data-testid="chat-list-status"
            className="mx-1 my-0.5 shrink-0 rounded-md bg-n-slate-3 px-2 py-1 text-xxs capitalize text-n-slate-12"
          >
            {statusOptions.find((o) => o.value === status)?.label}
          </span>
        )}
      </div>
      <div className="flex items-center gap-1">
        {hasAppliedFilters && !hasActiveFolder && (
          <div className="relative">
            <Button
              id={SAVE_FILTER_TOGGLE_ID}
              icon="ph-floppy-disk"
              color="slate"
              variant="faded"
              size="xs"
              title={t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')}
              aria-label={t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')}
              onClick={onAddFolder}
            />
            {savePanel && <div className={cx('absolute z-50 mt-2', panelSide)}>{savePanel}</div>}
          </div>
        )}
        {hasActiveFolder ? (
          <>
            <div className="relative">
              <Button
                id={FILTER_TOGGLE_ID}
                icon="ph-pencil-simple-line"
                color="slate"
                variant="faded"
                size="xs"
                title={t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')}
                aria-label={t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')}
                onClick={onOpenFilters}
              />
              {filterPanel && (
                <div className={cx('absolute z-50 mt-2', panelSide)}>{filterPanel}</div>
              )}
            </div>
            <Button
              icon="ph-trash"
              color="ruby"
              variant="faded"
              size="xs"
              title={t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')}
              aria-label={t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')}
              onClick={onDeleteFolder}
            />
          </>
        ) : (
          <div className="relative">
            <Button
              id={FILTER_TOGGLE_ID}
              icon="ph-funnel-simple"
              color="slate"
              variant="faded"
              size="xs"
              title={t('FILTER.TOOLTIP_LABEL')}
              aria-label={t('FILTER.TOOLTIP_LABEL')}
              onClick={onOpenFilters}
            />
            {filterPanel && (
              <div className={cx('absolute z-50 mt-2', panelSide)}>{filterPanel}</div>
            )}
          </div>
        )}
        <DropdownContainer
          id="chat-sort-menu"
          trigger={({ toggle, triggerProps }) => (
            <Button
              {...triggerProps}
              icon="ph-arrows-down-up"
              color="slate"
              variant="faded"
              size="xs"
              title={sortLabel}
              aria-label={sortLabel}
              onClick={toggle}
            />
          )}
        >
          <div
            className={cx(
              'absolute top-full z-40 mt-1 w-72 rounded-xl border border-n-weak bg-n-alpha-3 p-4 backdrop-blur-[100px]',
              expanded ? 'right-0' : 'left-0',
            )}
          >
            {/* show-status-filter: com filtros ou pasta, o status vem das condições */}
            {!filteredView && (
              <div className="mb-4 flex items-center justify-between gap-2">
                <span className="truncate text-sm text-n-slate-12">
                  {t('CHAT_LIST.CHAT_SORT.STATUS')}
                </span>
                <SelectMenu
                  label={t('CHAT_LIST.CHAT_SORT.STATUS')}
                  value={status}
                  options={statusOptions}
                  onChange={onStatusChange}
                  position={subMenuPosition}
                />
              </div>
            )}
            <div className="flex items-center justify-between gap-2">
              <span className="truncate text-sm text-n-slate-12">
                {t('CHAT_LIST.CHAT_SORT.ORDER_BY')}
              </span>
              <SelectMenu
                label={t('CHAT_LIST.CHAT_SORT.ORDER_BY')}
                value={sortBy}
                options={sortOptions}
                onChange={onSortChange}
                position={subMenuPosition}
              />
            </div>
          </div>
        </DropdownContainer>
        {/* SwitchLayout.vue */}
        <Button
          icon={expanded ? 'ph-arrow-line-left' : 'ph-arrow-line-right'}
          color="slate"
          variant="faded"
          size="xs"
          title={switchLabel}
          aria-label={switchLabel}
          onClick={onToggleLayout}
          className="hidden flex-shrink-0 md:inline-flex rtl:rotate-180"
        />
      </div>
    </div>
  )
}
