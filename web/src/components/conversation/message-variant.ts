// Regras de components-next/message/Message.vue (variant, orientation) e MessageList.vue (shouldGroupWithNext).
import type { Message } from '../../api/types'

/** Mensagem da thread: as do servidor mais as pendentes do envio otimista. */
export type ThreadMessage = Omit<Message, 'status'> & { status: Message['status'] | 'progress' }

export type Variant = 'user' | 'agent' | 'activity' | 'private' | 'bot' | 'error' | 'template'

export type Orientation = 'left' | 'right' | 'center'

const isBot = (m: ThreadMessage) => !m.sender || m.sender.type === 'agent_bot'

export function variantOf(m: ThreadMessage): Variant {
  if (m.private) return 'private'
  if (m.status === 'failed') return 'error'
  if (m.message_type === 1 && m.status !== 'progress' && isBot(m)) return 'bot'
  switch (m.message_type) {
    case 2:
      return 'activity'
    case 1:
      return 'agent'
    case 3:
      return 'template'
    default:
      return 'user'
  }
}

export function orientationOf(m: ThreadMessage): Orientation {
  if (m.message_type === 2) return 'center'
  // Pendente, bot e agente ficam à direita; o cliente, à esquerda.
  if (m.status === 'progress' || !m.sender || m.sender.type !== 'contact') return 'right'
  return 'left'
}

export function groupsWithNext(current: ThreadMessage, next: ThreadMessage | undefined): boolean {
  if (!next || next.status === 'failed') return false
  if (next.sender?.id !== current.sender?.id) return false
  if (next.message_type === 3 && current.message_type === 3) return false
  if (next.message_type !== current.message_type) return false
  return Math.floor(next.created_at / 60) === Math.floor(current.created_at / 60)
}
