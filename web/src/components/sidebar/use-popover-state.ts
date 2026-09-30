// Port de usePopoverState: o popover da sidebar recolhida abre no hover e fecha com atraso.
import { useCallback, useEffect, useRef, useState } from 'react'

export type ActivePopover = { name: string; top: number; left: number }

const FALLBACK_HEIGHT = 300

export function usePopoverState() {
  const [active, setActive] = useState<ActivePopover | null>(null)
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  const cancel = useCallback(() => clearTimeout(timer.current), [])

  const close = useCallback(() => {
    clearTimeout(timer.current)
    setActive(null)
  }, [])

  const scheduleClose = useCallback((delay: number) => {
    clearTimeout(timer.current)
    timer.current = setTimeout(() => setActive(null), delay)
  }, [])

  // A posição é relativa ao <aside>; se o popover estourar a janela, sobe o quanto precisar.
  const open = useCallback((name: string, trigger: HTMLElement, aside: HTMLElement | null) => {
    clearTimeout(timer.current)
    const asideRect = aside?.getBoundingClientRect()
    const { top } = trigger.getBoundingClientRect()
    const viewportTop =
      top + FALLBACK_HEIGHT > window.innerHeight - 20
        ? Math.max(20, window.innerHeight - FALLBACK_HEIGHT - 20)
        : top
    setActive({
      name,
      top: viewportTop - (asideRect?.top ?? 0),
      left: (asideRect?.width ?? 0) + 8,
    })
  }, [])

  useEffect(() => {
    window.addEventListener('blur', close)
    document.addEventListener('mouseleave', close)
    return () => {
      clearTimeout(timer.current)
      window.removeEventListener('blur', close)
      document.removeEventListener('mouseleave', close)
    }
  }, [close])

  return { active, open, close, cancel, scheduleClose }
}
