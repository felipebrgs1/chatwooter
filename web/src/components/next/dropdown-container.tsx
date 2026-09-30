// Port de components-next/dropdown-menu/base/DropdownContainer.vue: abre/fecha o menu pelo gatilho
// e fecha com clique fora ou Esc.
import { useCallback, useEffect, useId, useRef, useState, type ReactNode } from 'react'

import { cx } from './cx'

export type DropdownTriggerArgs = {
  open: boolean
  toggle: () => void
  close: () => void
  /** Espalhe no gatilho: id e o realce (`bg-n-alpha-1`) enquanto aberto. */
  triggerProps: { id: string; className?: string }
}

type Props = {
  id?: string
  trigger: (args: DropdownTriggerArgs) => ReactNode
  children: ReactNode | ((args: { close: () => void }) => ReactNode)
  onClose?: () => void
  /** Classes da raiz (no Vue, as que o pai põe no componente caem aqui). */
  className?: string
}

export function DropdownContainer({ id, trigger, children, onClose, className }: Props) {
  const generated = useId()
  const baseId = id ?? generated
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  const close = useCallback(() => {
    setOpen(false)
    onClose?.()
  }, [onClose])

  useEffect(() => {
    if (!open) return
    const onPointerDown = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) close()
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') close()
    }
    document.addEventListener('mousedown', onPointerDown)
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('mousedown', onPointerDown)
      document.removeEventListener('keydown', onKeyDown)
    }
  }, [open, close])

  // O .vue usa `space-y-2` (Tailwind v3: margin-top no corpo, que é absoluto). No v4 o space-y vira
  // margin-bottom de quem não é o último, e o gatilho ganharia 8px ao abrir — por isso o mt-2 no corpo.
  return (
    <div ref={ref} className={cx('relative', className)}>
      {trigger({
        open,
        toggle: () => (open ? close() : setOpen(true)),
        close,
        triggerProps: { id: `${baseId}-trigger`, className: open ? 'bg-n-alpha-1' : undefined },
      })}
      {open && (
        <div id={`${baseId}-body`} className="absolute mt-2">
          {typeof children === 'function' ? children({ close }) : children}
        </div>
      )}
    </div>
  )
}
