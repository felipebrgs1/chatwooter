// Rolagem da thread (MessagesView.vue): abre no fim, segue mensagens novas se o agente está embaixo,
// mantém a posição ao carregar mensagens antigas e pede mais ao chegar perto do topo.
import { useCallback, useLayoutEffect, useRef, type RefObject } from 'react'

import type { ThreadMessage } from './message-variant'

const NEAR_EDGE = 100

type Options = { hasOlder: boolean; isLoadingOlder: boolean; onLoadOlder: () => void }

export function useThreadScroll(
  ref: RefObject<HTMLDivElement | null>,
  messages: ThreadMessage[],
  options: Options,
) {
  const stickToBottom = useRef(true)
  const previous = useRef<{ first?: number; last?: number; height: number }>({ height: 0 })

  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const first = messages[0]?.id
    const last = messages.at(-1)
    const before = previous.current

    if (before.last === undefined) {
      el.scrollTop = el.scrollHeight
    } else if (first !== before.first && last?.id === before.last) {
      el.scrollTop += el.scrollHeight - before.height
    } else if (last?.id !== before.last && (stickToBottom.current || (last && last.id < 0))) {
      // nova mensagem: segue se já estava no fim; o envio do próprio agente sempre leva ao fim
      el.scrollTop = el.scrollHeight
      stickToBottom.current = true
    }
    previous.current = { first, last: last?.id, height: el.scrollHeight }
  }, [messages, ref])

  const { hasOlder, isLoadingOlder, onLoadOlder } = options
  return useCallback(() => {
    const el = ref.current
    if (!el) return
    stickToBottom.current = el.scrollHeight - el.scrollTop - el.clientHeight < NEAR_EDGE
    if (el.scrollTop < NEAR_EDGE && hasOlder && !isLoadingOlder) onLoadOlder()
  }, [ref, hasOlder, isLoadingOlder, onLoadOlder])
}
