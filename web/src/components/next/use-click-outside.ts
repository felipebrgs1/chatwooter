// vOnClickOutside do @vueuse: chama `onOutside` no clique fora do elemento enquanto `active`.
import { useEffect, useRef, type RefObject } from 'react'

export function useClickOutside(
  ref: RefObject<HTMLElement | null>,
  active: boolean,
  onOutside: () => void,
) {
  const callback = useRef(onOutside)
  useEffect(() => {
    callback.current = onOutside
  })
  useEffect(() => {
    if (!active) return
    const onPointerDown = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) callback.current()
    }
    document.addEventListener('mousedown', onPointerDown)
    return () => document.removeEventListener('mousedown', onPointerDown)
  }, [ref, active])
}
