// Port de components-next/filter/inputs/FilterSelect.vue: escolhe atributo, operador ou AND/OR.
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button, type ButtonVariant } from '../button'
import { cx } from '../cx'
import { DropdownBody, DropdownItem, DropdownSection } from '../dropdown-base'
import { DropdownContainer } from '../dropdown-container'
import { Icon } from '../icon'
import { DROPDOWN_SEARCH_THRESHOLD, matches } from './dropdown-search'
import type { SelectOption } from './use-conversation-filter-types'

const DROPDOWN_MAX_HEIGHT = 340

type Props = {
  value: string
  options: SelectOption[]
  onChange: (value: string) => void
  variant?: ButtonVariant
  hideIcon?: boolean
  className?: string
}

export function FilterSelect({
  value,
  options,
  onChange,
  variant = 'faded',
  hideIcon,
  className,
}: Props) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [openUp, setOpenUp] = useState(false)
  const triggerRef = useRef<HTMLDivElement>(null)
  const selected = options.find((o) => o.value === value)
  const showSearch = options.length > DROPDOWN_SEARCH_THRESHOLD
  // cabeçalhos de grupo não são selecionáveis: somem quando a busca estreita a lista
  const results = search.trim()
    ? options.filter((o) => !o.disabled && matches(o.label, search))
    : options
  const icon = hideIcon ? undefined : (selected?.icon ?? 'ph-caret-down')

  return (
    <div ref={triggerRef} className={className}>
      <DropdownContainer
        trigger={({ toggle }) => (
          <Button
            size="sm"
            color="slate"
            variant={variant}
            icon={icon}
            trailingIcon={!selected?.icon}
            label={selected?.label}
            onClick={() => {
              setSearch('')
              // abre para cima quando falta espaço embaixo (dropdownPosition)
              const top = triggerRef.current?.getBoundingClientRect().top ?? 0
              setOpenUp(window.innerHeight - top < DROPDOWN_MAX_HEIGHT)
              toggle()
            }}
          />
        )}
      >
        {({ close }) => (
          <DropdownBody strong className={cx('min-w-56 z-50', openUp ? 'bottom-0' : 'top-0')}>
            {showSearch && (
              <div className="relative">
                <Icon name="ph-magnifying-glass" className="absolute size-4 left-2 top-2" />
                <input
                  autoFocus
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="w-full p-1.5 pl-8 rounded-lg text-n-slate-11 bg-n-alpha-1"
                  placeholder={t('COMBOBOX.SEARCH_PLACEHOLDER')}
                />
              </div>
            )}
            <DropdownSection className="[&>ul]:max-h-72">
              {results.map((option) =>
                option.disabled ? (
                  <li
                    key={option.value}
                    className="px-2 py-1.5 text-xs font-medium text-n-slate-10 select-none"
                  >
                    {option.label}
                  </li>
                ) : (
                  <DropdownItem
                    key={option.value}
                    label={option.label}
                    icon={option.icon}
                    onClick={() => {
                      onChange(option.value)
                      close()
                    }}
                  />
                ),
              )}
              {!results.length && (
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
    </div>
  )
}
