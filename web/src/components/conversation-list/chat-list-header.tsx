// Port de components/ChatListHeader.vue + ConversationBasicFilter.vue (status e ordenação) + SwitchLayout.vue.
// Filtros avançados e pastas ficam para as próximas fatias.
import { useTranslation } from 'react-i18next'

import { Button } from '../next/button'
import { cx } from '../next/cx'
import { DropdownContainer } from '../next/dropdown-container'
import { SORTS, STATUSES, type ConversationsSearch } from './search'
import { SelectMenu } from './select-menu'

type Props = {
  title: string
  status: ConversationsSearch['status']
  sortBy: ConversationsSearch['sort_by']
  onStatusChange: (status: ConversationsSearch['status']) => void
  onSortChange: (sortBy: ConversationsSearch['sort_by']) => void
  /** isOnExpandedLayout: os menus abrem alinhados à direita. */
  expanded?: boolean
  onToggleLayout?: () => void
}

export function ChatListHeader({
  title,
  status,
  sortBy,
  onStatusChange,
  onSortChange,
  expanded = false,
  onToggleLayout,
}: Props) {
  const { t } = useTranslation()

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
    <div className="flex h-[3.25rem] items-center justify-between gap-2 px-3">
      <div className="flex min-w-0 items-center justify-center">
        <h1 className="truncate text-base font-medium text-n-slate-12" title={title}>
          {title}
        </h1>
        <span
          data-testid="chat-list-status"
          className="mx-1 my-0.5 shrink-0 rounded-md bg-n-slate-3 px-2 py-1 text-xxs capitalize text-n-slate-12"
        >
          {statusOptions.find((o) => o.value === status)?.label}
        </span>
      </div>
      <div className="flex items-center gap-1">
        {/* ponto de extensão: filtros avançados entram aqui */}
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
            <div className="flex items-center justify-between gap-2">
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
            <div className="mt-4 flex items-center justify-between gap-2">
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
