// Port de components/Accordion/AccordionItem.vue: seção recolhível do painel do contato.
import type { ReactNode } from 'react'

import { cx } from '../../next/cx'
import { Icon } from '../../next/icon'

type Props = {
  title: string
  isOpen: boolean
  onToggle: () => void
  /** Sem padding no conteúdo (o conteúdo cuida do próprio espaçamento). */
  compact?: boolean
  children: ReactNode
}

export function AccordionItem({ title, isOpen, onToggle, compact = false, children }: Props) {
  return (
    <div className="text-sm">
      {/* cursor-grab/drag-handle: a reordenação por arrasto entra com os demais acordeões */}
      <button
        type="button"
        aria-expanded={isOpen}
        className={cx(
          'flex items-center select-none w-full rounded-lg bg-n-slate-2 outline outline-1 outline-n-weak m-0 cursor-grab justify-between py-2 px-4',
          isOpen && 'rounded-bl-none rounded-br-none',
        )}
        onClick={(e) => {
          e.stopPropagation()
          onToggle()
        }}
      >
        <div className="flex justify-between">
          <h5 className="text-n-slate-12 text-sm mb-0 py-0 pr-2 pl-0">{title}</h5>
        </div>
        <div className="flex flex-row">
          <div className="flex justify-end w-3 text-n-blue-11 cursor-pointer">
            <Icon name={isOpen ? 'ph-minus-bold' : 'ph-plus-bold'} className="size-4" />
          </div>
        </div>
      </button>
      {isOpen && (
        <div
          className={cx(
            'outline outline-1 outline-n-weak -mt-[-1px] border-t-0 rounded-br-lg rounded-bl-lg',
            compact ? 'p-0' : 'px-2 py-4',
          )}
        >
          {children}
        </div>
      )}
    </div>
  )
}
