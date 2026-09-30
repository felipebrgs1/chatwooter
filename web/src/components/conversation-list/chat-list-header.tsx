// Port de components/ChatListHeader.vue + ConversationBasicFilter.vue (status e ordenação).
// Filtros avançados, pastas e troca de layout ficam para as próximas fatias.
import { useTranslation } from 'react-i18next'

import { Button } from '../next/button'
import { DropdownContainer } from '../next/dropdown-container'
import { SORTS, STATUSES, type ConversationsSearch } from './search'
import { SelectMenu } from './select-menu'

type Props = {
  title: string
  status: ConversationsSearch['status']
  sortBy: ConversationsSearch['sort_by']
  onStatusChange: (status: ConversationsSearch['status']) => void
  onSortChange: (sortBy: ConversationsSearch['sort_by']) => void
}

export function ChatListHeader({ title, status, sortBy, onStatusChange, onSortChange }: Props) {
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
        {/* ponto de extensão: filtros avançados e troca de layout entram aqui */}
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
          <div className="absolute left-0 top-full z-40 mt-1 w-72 rounded-xl border border-n-weak bg-n-alpha-3 p-4 backdrop-blur-[100px]">
            <div className="flex items-center justify-between gap-2">
              <span className="truncate text-sm text-n-slate-12">
                {t('CHAT_LIST.CHAT_SORT.STATUS')}
              </span>
              <SelectMenu
                label={t('CHAT_LIST.CHAT_SORT.STATUS')}
                value={status}
                options={statusOptions}
                onChange={onStatusChange}
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
              />
            </div>
          </div>
        </DropdownContainer>
      </div>
    </div>
  )
}
