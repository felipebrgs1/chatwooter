// Port de components-next/filter/inputs/SingleSelect.vue: um valor, com busca local ou assíncrona.
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '../button'
import { DropdownBody, DropdownItem, DropdownSection } from '../dropdown-base'
import { DropdownContainer } from '../dropdown-container'
import { Icon } from '../icon'
import type { FilterOption } from './filter-query'
import { matches } from './dropdown-search'
import type { ValueOption } from './use-conversation-filter-types'

type Props = {
  value: FilterOption | FilterOption[] | null
  options: ValueOption[]
  onChange: (value: FilterOption | null) => void
  /** As opções vêm de quem busca (onSearch); o filtro local não se aplica. */
  asyncSearch?: boolean
  isSearching?: boolean
  onSearch?: (query: string) => void
  disableSearch?: boolean
  searchPlaceholder?: string
  dropdownMaxHeight?: string
}

export function SingleSelect({
  value,
  options,
  onChange,
  asyncSearch = false,
  isSearching = false,
  onSearch,
  disableSearch = false,
  searchPlaceholder,
  dropdownMaxHeight = 'max-h-80',
}: Props) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const results =
    asyncSearch || !search.trim() ? options : options.filter((o) => matches(o.name, search))
  // o valor às vezes chega como lista (edição de pasta): vale o primeiro
  const current = Array.isArray(value) ? value[0] : value
  const selected =
    current && 'id' in current
      ? (options.find((o) => o.id === current.id) ??
        // na busca assíncrona o escolhido pode não estar entre as opções atuais
        (asyncSearch ? { ...current, name: String(current.name) } : null))
      : null

  const toggle = (option: ValueOption) => {
    onChange(current && current.id === option.id ? null : { id: option.id, name: option.name })
  }

  return (
    <DropdownContainer
      className="min-w-0"
      trigger={({ toggle: open }) =>
        selected ? (
          <Button
            size="sm"
            color="slate"
            variant="faded"
            icon={selected.icon}
            label={selected.name}
            onClick={open}
          />
        ) : (
          <Button size="sm" color="slate" variant="faded" onClick={open}>
            <Icon name="ph-plus" className="text-n-slate-11" />
            <span className="text-n-slate-11 min-w-0 truncate">{t('COMBOBOX.PLACEHOLDER')}</span>
          </Button>
        )
      }
    >
      {({ close }) => (
        <DropdownBody strong className="top-0 min-w-56 z-50">
          {!disableSearch && (
            <div className="relative">
              <Icon name="ph-magnifying-glass" className="absolute size-4 left-2 top-2" />
              <input
                autoFocus
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value)
                  onSearch?.(e.target.value)
                }}
                className="p-1.5 pl-8 text-n-slate-11 bg-n-alpha-1 rounded-lg w-full"
                placeholder={searchPlaceholder || t('COMBOBOX.SEARCH_PLACEHOLDER')}
              />
            </div>
          )}
          <DropdownSection height={dropdownMaxHeight}>
            {isSearching ? (
              <DropdownItem disabled>{t('DROPDOWN_MENU.SEARCHING')}</DropdownItem>
            ) : results.length ? (
              results.map((option) => (
                <DropdownItem
                  key={String(option.id)}
                  icon={option.icon}
                  onClick={() => {
                    toggle(option)
                    close()
                  }}
                  label={
                    <>
                      {option.name}
                      {selected?.id === option.id && (
                        <Icon name="ph-check" className="text-n-blue-11 pointer-events-none" />
                      )}
                    </>
                  }
                />
              ))
            ) : (
              <DropdownItem disabled>
                {search
                  ? t('COMBOBOX.EMPTY_SEARCH_RESULTS', { searchTerm: search })
                  : t('COMBOBOX.EMPTY_STATE')}
              </DropdownItem>
            )}
          </DropdownSection>
        </DropdownBody>
      )}
    </DropdownContainer>
  )
}
