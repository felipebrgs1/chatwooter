// Port de components/ui/ContextMenu.vue: menu fixo no ponto do clique, preso à janela, que fecha quando o
// foco sai dele. A trava de scroll (contextMenuElementTarget) fica com quem abre o menu.
import { useLayoutEffect, useRef, useState, type FocusEvent, type ReactNode } from 'react'
import { createPortal } from 'react-dom'

const PADDING = 16

type Props = {
  x: number
  y: number
  onClose: () => void
  children: ReactNode
}

export function ContextMenu({ x, y, onClose, children }: Props) {
  const ref = useRef<HTMLDivElement>(null)
  const [position, setPosition] = useState({ left: x, top: y })

  useLayoutEffect(() => {
    const menu = ref.current
    if (!menu) return
    const { width, height } = menu.getBoundingClientRect()
    let left = x
    let top = y
    if (left + width > window.innerWidth - PADDING) left = window.innerWidth - width - PADDING
    if (top + height > window.innerHeight - PADDING) top = window.innerHeight - height - PADDING
    setPosition({ left: Math.max(PADDING, left), top: Math.max(PADDING, top) })
    menu.focus()
  }, [x, y])

  // mantém aberto enquanto o foco fica dentro (ex.: a busca de etiquetas)
  const onBlur = (event: FocusEvent<HTMLDivElement>) => {
    if (ref.current?.contains(event.relatedTarget as Node | null)) return
    onClose()
  }

  return createPortal(
    <div
      ref={ref}
      className="fixed outline-none z-[9999] cursor-pointer"
      style={{ top: position.top, left: position.left }}
      tabIndex={0}
      onBlur={onBlur}
    >
      {children}
    </div>,
    document.body,
  )
}
