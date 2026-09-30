// Port de components-next/tabbar/TabBar.vue. O indicador deslizante vira o fundo da aba ativa.
import { Fragment, type KeyboardEvent } from 'react'

import { cx } from './cx'

export type Tab = { value: string; label: string; count?: number }

type Props = {
  id: string
  tabs: Tab[]
  active: string
  onChange: (value: string) => void
  className?: string
}

export function TabBar({ id, tabs, active, onChange, className }: Props) {
  function onKeyDown(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
    if (!step) return
    const next = tabs[(index + step + tabs.length) % tabs.length]
    onChange(next.value)
    document.getElementById(`${id}-${next.value}`)?.focus()
  }

  return (
    <div
      id={id}
      role="tablist"
      className={cx(
        'relative flex items-center h-8 rounded-lg bg-n-alpha-1 dark:bg-n-solid-1 w-fit transition-all duration-200 ease-out has-[button:active]:scale-[1.01]',
        className,
      )}
    >
      {tabs.map((tab, index) => {
        const selected = tab.value === active
        const nextSelected = tabs[index + 1]?.value === active
        return (
          <Fragment key={tab.value}>
            <button
              id={`${id}-${tab.value}`}
              type="button"
              role="tab"
              aria-selected={selected}
              tabIndex={selected ? 0 : -1}
              onClick={() => onChange(tab.value)}
              onKeyDown={(e) => onKeyDown(e, index)}
              className={cx(
                'relative z-10 px-4 truncate py-1.5 h-8 text-sm border-0 outline-1 rounded-lg transition-all duration-200 ease-out hover:text-n-brand active:scale-[1.02]',
                selected
                  ? 'text-n-blue-11 scale-100 bg-n-solid-active shadow-sm outline outline-n-container'
                  : 'text-n-slate-10 scale-[0.98] outline-transparent',
              )}
            >
              {tab.label}
              {tab.count !== undefined && ` (${tab.count})`}
            </button>
            {index < tabs.length - 1 && (
              <div
                className={cx(
                  'w-px h-3.5 rounded my-auto transition-colors duration-300 ease-in-out shrink-0',
                  !selected && !nextSelected ? 'bg-n-strong' : 'bg-transparent',
                )}
              />
            )}
          </Fragment>
        )
      })}
    </div>
  )
}
