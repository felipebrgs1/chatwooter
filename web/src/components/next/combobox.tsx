// Port de components-next/combobox/ComboBox.vue + ComboBoxDropdown.vue: botão + lista com busca.
import { useCallback, useEffect, useId, useMemo, useRef, useState, type KeyboardEvent } from 'react'

import { Button } from './button'
import { cx } from './cx'
import { Icon } from './icon'
import { useSearchableList } from './use-searchable-list'

export type ComboboxOption = {
  value: string | number
  label: string
  icon?: string
  /** Opção desabilitada é um cabeçalho de grupo: não é selecionável e some durante a busca. */
  disabled?: boolean
}

type Props = {
  disabled?: boolean
  onOpen?: () => void
  displayLabel?: string
  useApiResults?: boolean
  id: string
  options: ComboboxOption[]
  value: ComboboxOption['value'] | null
  onChange: (value: ComboboxOption['value']) => void
  placeholder: string
  searchPlaceholder: string
  emptyState: string
  /** Busca no servidor: chamado 300ms depois de parar de digitar. O filtro local continua valendo. */
  onSearch?: (query: string) => void
  className?: string
  dropdownClassName?: string
  listClassName?: string
}

const isHeader = (option: ComboboxOption) => option.disabled === true
const getText = (option: ComboboxOption) => option.label

export function Combobox({
  disabled = false,
  onOpen,
  displayLabel,
  useApiResults = false,
  id,
  options,
  value,
  onChange,
  placeholder,
  searchPlaceholder,
  emptyState,
  onSearch,
  className,
  dropdownClassName,
  listClassName,
}: Props) {
  const listId = useId()
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(-1)
  const ref = useRef<HTMLDivElement>(null)
  const searchRef = useRef<HTMLInputElement>(null)
  const { query, setQuery, visible, isEmpty } = useSearchableList(options, getText, isHeader)

  const close = useCallback(() => {
    setOpen(false)
    setQuery('')
    setActive(-1)
  }, [setQuery])

  const selected = options.find((o) => String(o.value) === String(value))
  const shown = useApiResults ? options : visible
  const selectable = useMemo(() => shown.filter((o) => !isHeader(o)), [shown])

  useEffect(() => {
    if (open) searchRef.current?.focus()
  }, [open])

  useEffect(() => {
    if (!open) return
    const onPointerDown = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) close()
    }
    document.addEventListener('mousedown', onPointerDown)
    return () => document.removeEventListener('mousedown', onPointerDown)
  }, [open, close])

  useEffect(() => {
    if (!onSearch || !open) return
    const timer = setTimeout(() => onSearch(query), 300)
    return () => clearTimeout(timer)
  }, [query, onSearch, open])

  function choose(option: ComboboxOption) {
    onChange(option.value)
    close()
  }

  function onKeyDown(event: KeyboardEvent) {
    if (!open) return
    if (event.key === 'Escape') {
      event.stopPropagation()
      close()
      ref.current?.querySelector('button')?.focus()
    } else if (event.key === 'ArrowDown') {
      event.preventDefault()
      setActive((i) => Math.min(i + 1, selectable.length - 1))
    } else if (event.key === 'ArrowUp') {
      event.preventDefault()
      setActive((i) => Math.max(i - 1, 0))
    } else if (event.key === 'Enter' && selectable[active]) {
      event.preventDefault()
      choose(selectable[active])
    }
  }

  const activeOption = selectable[active]

  return (
    <div
      id={id}
      ref={ref}
      onKeyDown={onKeyDown}
      className={cx('relative w-full min-w-0 group/combobox', className)}
    >
      <Button
        color="slate"
        variant="outline"
        icon={selected?.icon ?? 'ph-caret-down'}
        trailingIcon={!selected?.icon}
        noAnimation
        size="md"
        disabled={disabled}
        label={selected ? selected.label : displayLabel || placeholder}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={open ? listId : undefined}
        className="justify-between! w-full px-3! py-2.5! h-8! bg-n-alpha-black2! font-normal outline-n-weak! group-hover/combobox:outline-n-slate-6! focus:outline-n-brand! text-n-slate-12"
        onClick={() => {
          if (open) close()
          else {
            setOpen(true)
            onOpen?.()
          }
        }}
      />
      {open && (
        <div
          id={`${id}-dropdown`}
          className={cx(
            'absolute z-50 w-full mt-1 transition-opacity duration-200 border rounded-md shadow-lg bg-n-solid-1 border-n-strong',
            dropdownClassName,
          )}
        >
          <div className="relative border-b border-n-strong">
            <Icon name="ph-magnifying-glass" className="absolute top-2.5 size-4 start-3" />
            <input
              ref={searchRef}
              type="search"
              value={query}
              onChange={(event) => {
                setQuery(event.target.value)
                setActive(-1)
              }}
              placeholder={searchPlaceholder}
              aria-controls={listId}
              aria-activedescendant={
                activeOption ? `${id}-option-${activeOption.value}` : undefined
              }
              className="w-full py-2 ps-10! pe-2! text-sm focus:outline-none border-none rounded-t-md bg-n-solid-1 text-n-slate-12"
            />
          </div>
          <ul
            id={listId}
            role="listbox"
            className={cx('py-1 mb-0 overflow-auto max-h-56', listClassName)}
          >
            {shown.map((option) =>
              isHeader(option) ? (
                <li
                  key={option.value}
                  id={`${id}-group-${option.value}`}
                  role="presentation"
                  className="px-3 py-1.5 text-xs font-medium text-n-slate-10 select-none"
                >
                  {option.label}
                </li>
              ) : (
                <li
                  key={option.value}
                  id={`${id}-option-${option.value}`}
                  role="option"
                  aria-selected={selected === option}
                  onClick={() => choose(option)}
                  className={cx(
                    'flex items-center justify-between w-full gap-2 px-3 py-2 text-sm transition-colors duration-150 cursor-pointer hover:bg-n-alpha-2',
                    (selected === option || activeOption === option) && 'bg-n-alpha-2',
                  )}
                >
                  <span
                    className={cx(
                      'flex items-center gap-2 text-n-slate-12',
                      selected === option && 'font-medium',
                    )}
                  >
                    {option.icon && <Icon name={option.icon} className="size-4 shrink-0" />}
                    {option.label}
                  </span>
                  {selected === option && (
                    <Icon name="ph-check" className="flex-shrink-0 size-4 text-n-slate-11" />
                  )}
                </li>
              ),
            )}
            {(useApiResults ? shown.length === 0 : isEmpty) && (
              <li className="px-3 py-2 text-sm text-n-slate-11">{emptyState}</li>
            )}
          </ul>
        </div>
      )}
    </div>
  )
}
