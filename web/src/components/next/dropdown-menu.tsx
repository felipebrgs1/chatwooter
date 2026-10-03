// Port de components-next/dropdown-menu/DropdownMenu.vue (com show-search).
import type { ReactNode } from 'react'

import { cx } from './cx'
import { Icon } from './icon'
import { SearchableList } from './searchable-list'
import { Spinner } from './spinner'

export type DropdownMenuItem = { value: string | number; label: string }

type Props<T extends DropdownMenuItem> = {
  id: string
  /** O menu é controlado por quem o abre; fechado não renderiza. */
  open: boolean
  items: T[]
  onSelect: (value: T['value']) => void
  onClose?: () => void
  selected?: T['value'] | null
  searchPlaceholder: string
  emptyState: string
  className?: string
  /** Conteúdo antes do rótulo (ícone, avatar...): o slot `thumbnail`. */
  renderItem?: (item: T) => ReactNode
  /** Slot `trailing-icon`. */
  renderTrailing?: (item: T) => ReactNode
  /** item.isSelected do original, para seleção múltipla. */
  isSelected?: (item: T) => boolean
  isLoading?: boolean
  /** Slot `footer`, fixo abaixo da lista. */
  footer?: ReactNode
  showSearch?: boolean
  isDisabled?: (item: T) => boolean
}

export function DropdownMenu<T extends DropdownMenuItem>({
  id,
  open,
  items,
  onSelect,
  onClose,
  selected,
  searchPlaceholder,
  emptyState,
  className,
  renderItem,
  renderTrailing,
  isSelected,
  isLoading = false,
  footer,
  showSearch = true,
  isDisabled,
}: Props<T>) {
  if (!open) return null

  return (
    <SearchableList
      items={items}
      getText={(item) => item.label}
      className={cx(
        'bg-n-alpha-3 backdrop-blur-[100px] border-0 outline outline-1 outline-n-container absolute rounded-xl z-50 flex flex-col min-w-[136px] shadow-lg pt-2 overflow-hidden',
        className,
      )}
    >
      {({ query, setQuery, visible, isEmpty }) => (
        <div id={id} className="contents">
          {showSearch && (
            <div className="relative shrink-0 px-2 mb-2">
              <Icon name="ph-magnifying-glass" className="absolute size-3.5 top-2.5 left-5" />
              <input
                // onMounted: a busca já abre focada
                autoFocus
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder={searchPlaceholder}
                className="w-full h-8 py-2 pl-10 pr-2 text-sm focus:outline-none border-none rounded-lg bg-n-alpha-black2 dark:bg-n-solid-1 text-n-slate-12"
              />
            </div>
          )}
          <div className="flex flex-col gap-2 overflow-y-auto min-h-0 px-2 pb-2">
            {isLoading && (
              <div className="flex items-center justify-center py-2">
                <Spinner size={24} />
              </div>
            )}
            {visible.map((item) => (
              <button
                key={item.value}
                id={`${id}-option-${item.value}`}
                type="button"
                disabled={isDisabled?.(item)}
                onClick={() => {
                  onSelect(item.value)
                  onClose?.()
                }}
                className={cx(
                  'inline-flex items-center justify-start w-full h-8 min-w-0 gap-2 px-2 py-1.5 transition-all duration-200 ease-in-out border-0 rounded-lg hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2 text-n-slate-12 disabled:cursor-not-allowed disabled:pointer-events-none disabled:opacity-50',
                  ((selected !== undefined &&
                    selected !== null &&
                    String(item.value) === String(selected)) ||
                    isSelected?.(item)) &&
                    'bg-n-alpha-1 dark:bg-n-solid-active',
                )}
              >
                {renderItem?.(item)}
                <span className="min-w-0 text-sm font-420 truncate">{item.label}</span>
                {renderTrailing?.(item)}
              </button>
            ))}
            {isEmpty && <p className="text-sm text-n-slate-11 px-2 py-1.5 mb-0">{emptyState}</p>}
          </div>
          {footer && <div className="shrink-0">{footer}</div>}
        </div>
      )}
    </SearchableList>
  )
}
