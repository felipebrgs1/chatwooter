// Port de composables/chatlist/useChatListKeyboardEvents.js: clica o card para preservar a rota/filtros.
import type { RefObject } from 'react'

import { useAltShortcut } from '../../shared/use-alt-shortcut'

export function useChatListKeyboardEvents(listRef: RefObject<HTMLElement | null>) {
  const navigate = (direction: number) => {
    const cards = Array.from(listRef.current?.querySelectorAll<HTMLElement>('a.conversation') ?? [])
    if (cards.length === 0) return
    const active = cards.findIndex((card) => card.getAttribute('aria-current') === 'page')
    const index = Math.max(0, Math.min(active + direction, cards.length - 1))
    cards[index].click()
  }

  useAltShortcut('KeyJ', () => navigate(-1), true)
  useAltShortcut('KeyK', () => navigate(1), true)
}
