// Port de components-next/Contacts/ContactsHeader/ContactHeader.vue.
// Filtros/segmentos, "mais ações" (criar, importar, exportar) e a nova conversa aparecem só visuais:
// entram com as próximas fatias de contatos.
import { useTranslation } from 'react-i18next'

import { Button } from '../next/button'
import { Icon } from '../next/icon'
import { Input } from '../next/input'
import type { ContactOrdering, ContactSort } from './contact-sort'
import { ContactSortMenu } from './contact-sort-menu'

type Props = {
  headerTitle: string
  showSearch?: boolean
  searchValue: string
  activeSort: ContactSort
  activeOrdering: ContactOrdering
  onSearch: (value: string) => void
  onSortChange: (sort: { sort: ContactSort; order: ContactOrdering }) => void
}

export function ContactHeader({
  headerTitle,
  showSearch = true,
  searchValue,
  activeSort,
  activeOrdering,
  onSearch,
  onSortChange,
}: Props) {
  const { t } = useTranslation()
  const placeholder = t('CONTACTS_LAYOUT.HEADER.SEARCH_PLACEHOLDER')

  return (
    <header className="sticky top-0 z-20 px-6">
      <div className="mx-auto flex w-full max-w-5xl items-start justify-between gap-2 py-6 sm:items-center">
        <h1 className="truncate text-xl font-medium text-n-slate-12">{headerTitle}</h1>
        <div className="flex flex-shrink-0 flex-col items-center gap-4 sm:flex-row">
          {showSearch && (
            <div className="flex w-full items-center gap-2">
              <Input
                type="search"
                value={searchValue}
                placeholder={placeholder}
                aria-label={placeholder}
                size="sm"
                inputClassName="h-8 [&:not(:focus)]:!outline-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-8 !py-1 rtl:!pr-8"
                className="w-full"
                onChange={(event) => onSearch(event.target.value)}
                prefix={
                  <Icon
                    name="ph-magnifying-glass"
                    className="absolute top-1/2 size-4 -translate-y-1/2 text-n-slate-11 ltr:left-2 rtl:right-2"
                  />
                }
              />
            </div>
          )}
          <div className="flex flex-shrink-0 items-center gap-4">
            <div className="flex items-center gap-2">
              <div className="relative">
                <Button
                  icon="ph-funnel-simple"
                  color="slate"
                  size="sm"
                  variant="ghost"
                  className="relative w-8"
                />
              </div>
              <ContactSortMenu
                activeSort={activeSort}
                activeOrdering={activeOrdering}
                onSortChange={onSortChange}
              />
              <Button icon="ph-dots-three-vertical" color="slate" variant="ghost" size="sm" />
            </div>
            <div className="h-4 w-px bg-n-strong" />
            <Button label={t('CONTACTS_LAYOUT.HEADER.MESSAGE_BUTTON')} size="sm" />
          </div>
        </div>
      </div>
    </header>
  )
}
