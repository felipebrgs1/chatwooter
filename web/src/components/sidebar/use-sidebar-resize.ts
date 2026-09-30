// Port de Sidebar.vue: onResizeStart / onResizeMove / onResizeEnd (limites do provider.js).
import { useEffect, useRef, useState, type MouseEvent, type TouchEvent } from 'react'

export const SIDEBAR_MIN_WIDTH = 56
export const SIDEBAR_MAX_WIDTH = 320
export const SIDEBAR_COLLAPSED_THRESHOLD = 160
export const SIDEBAR_DEFAULT_WIDTH = 200

/** Recolhida = abaixo do limiar; no mobile a sidebar é sempre expandida (flyout). */
export function isCollapsed(width: number, isMobile: boolean) {
  return !isMobile && width < SIDEBAR_COLLAPSED_THRESHOLD
}

const clamp = (width: number) =>
  Math.max(SIDEBAR_MIN_WIDTH, Math.min(SIDEBAR_MAX_WIDTH, Math.round(width)))

type WidthChange = (width: number, commit: boolean) => void

export function useSidebarResize(width: number, onWidthChange: WidthChange) {
  const [resizing, setResizing] = useState(false)
  const drag = useRef({ startX: 0, startWidth: 0, width: 0 })
  const callback = useRef(onWidthChange)
  useEffect(() => {
    callback.current = onWidthChange
  })

  useEffect(() => {
    if (!resizing) return
    const clientX = (e: globalThis.MouseEvent | globalThis.TouchEvent) =>
      'touches' in e ? e.touches[0].clientX : e.clientX

    const onMove = (e: globalThis.MouseEvent | globalThis.TouchEvent) => {
      if (e.cancelable) e.preventDefault()
      drag.current.width = clamp(drag.current.startWidth + clientX(e) - drag.current.startX)
      callback.current(drag.current.width, false)
    }
    // Abaixo do limiar encaixa no mínimo (onResizeEnd)
    const onEnd = () => {
      const { width: final } = drag.current
      callback.current(final < SIDEBAR_COLLAPSED_THRESHOLD ? SIDEBAR_MIN_WIDTH : final, true)
      setResizing(false)
    }

    document.addEventListener('mousemove', onMove)
    document.addEventListener('touchmove', onMove, { passive: false })
    document.addEventListener('mouseup', onEnd)
    document.addEventListener('touchend', onEnd)
    Object.assign(document.body.style, { cursor: 'col-resize', userSelect: 'none' })
    return () => {
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('touchmove', onMove)
      document.removeEventListener('mouseup', onEnd)
      document.removeEventListener('touchend', onEnd)
      Object.assign(document.body.style, { cursor: '', userSelect: '' })
    }
  }, [resizing])

  const start = (x: number) => {
    drag.current = { startX: x, startWidth: width, width }
    setResizing(true)
  }

  return {
    resizing,
    handleProps: {
      onMouseDown: (e: MouseEvent) => {
        start(e.clientX)
        e.preventDefault()
      },
      onTouchStart: (e: TouchEvent) => start(e.touches[0].clientX),
    },
  }
}
