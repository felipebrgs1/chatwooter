// Port de components-next/filter/inputs/MultiSelect.vue: vários valores, mostrados como chips.
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '../button'
import { DropdownBody, DropdownItem, DropdownSection } from '../dropdown-base'
import { DropdownContainer } from '../dropdown-container'
import { Icon } from '../icon'
import type { FilterOption } from './filter-query'
import { DROPDOWN_SEARCH_THRESHOLD, matches } from './dropdown-search'
import type { ValueOption } from './use-conversation-filter-types'

type Props = {
  value: FilterOption[]
  options: ValueOption[]
  onChange: (value: FilterOption[]) => void
  maxChips?: number
  dropdownMaxHeight?: string
}

function OptionMark({ option }: { option: ValueOption }) {
  if (option.color)
    return (
      <span
        className="flex-shrink-0 rounded-full size-1.5"
        // cor da etiqueta vem do banco (labels.color)
        style={{ backgroundColor: option.color }}
      />
    )
  return option.icon ? <Icon name={option.icon} className="flex-shrink-0" /> : null
}

export function MultiSelect({
  value,
  options,
  onChange,
  maxChips = 3,
  dropdownMaxHeight = 'max-h-80',
}: Props) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const selectedIds = value.map((v) => v.id)
  const selectedItems = options.filter((o) => selectedIds.includes(o.id))
  // "+1 more" ocupa o mesmo espaço que o chip: nesse caso mostra o chip
  const visible =
    selectedItems.length === maxChips + 1 ? selectedItems : selectedItems.slice(0, maxChips)
  const remaining = selectedItems.length === maxChips + 1 ? [] : selectedItems.slice(maxChips)
  const results = search.trim() ? options.filter((o) => matches(o.name, search)) : options

  const toggle = (option: ValueOption) => {
    const picked = { id: option.id, name: option.name }
    onChange(
      selectedIds.includes(option.id)
        ? value.filter((v) => v.id !== option.id)
        : [...value, picked],
    )
  }

  return (
    <DropdownContainer
      className="min-w-0"
      trigger={({ toggle: open }) => {
        const onOpen = () => {
          setSearch('')
          open()
        }
        return selectedItems.length ? (
          <button
            type="button"
            className="bg-n-alpha-2 py-2 rounded-lg h-8 flex items-center px-0 max-w-full"
            onClick={onOpen}
          >
            {visible.map((item) => (
              <div
                key={String(item.id)}
                className="px-3 border-e border-n-weak text-n-slate-12 text-sm flex gap-2 items-center max-w-[100px] min-w-0"
              >
                <OptionMark option={item} />
                <span className="truncate">{item.name}</span>
              </div>
            ))}
            {remaining.length > 0 && (
              <div
                title={remaining.map((item) => item.name).join(', ')}
                className="px-3 border-e border-n-weak text-n-slate-12 text-sm flex gap-2 items-center max-w-[100px] flex-shrink-0"
              >
                <span className="truncate">{t('COMBOBOX.MORE', { count: remaining.length })}</span>
              </div>
            )}
            <div className="flex items-center border-none px-3 gap-2 flex-shrink-0">
              <Icon name="ph-plus" />
            </div>
          </button>
        ) : (
          <Button size="sm" color="slate" variant="faded" onClick={onOpen}>
            <Icon name="ph-plus" className="text-n-slate-11" />
            <span className="text-n-slate-11 min-w-0 truncate">{t('COMBOBOX.PLACEHOLDER')}</span>
          </Button>
        )
      }}
    >
      <DropdownBody strong className="top-0 min-w-48 z-50">
        {options.length > DROPDOWN_SEARCH_THRESHOLD && (
          <div className="relative">
            <Icon name="ph-magnifying-glass" className="absolute size-4 start-2 top-2" />
            <input
              autoFocus
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="p-1.5 ps-8 text-n-slate-11 bg-n-alpha-1 rounded-lg w-full"
              placeholder={t('COMBOBOX.SEARCH_PLACEHOLDER')}
            />
          </div>
        )}
        <DropdownSection height={dropdownMaxHeight}>
          {results.length ? (
            results.map((option) => (
              // preserve-open: a lista continua aberta para marcar vários
              <DropdownItem
                key={String(option.id)}
                iconSlot={<OptionMark option={option} />}
                onClick={() => toggle(option)}
                label={
                  <>
                    {option.name}
                    {selectedIds.includes(option.id) && (
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
    </DropdownContainer>
  )
}
