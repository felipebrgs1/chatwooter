// Porta de MessageMeta.vue (isSent/isDelivered/isRead) só para os canais do v1: WhatsApp e Telegram.
// Os demais canais seguem a regra da inbox de API (status real do servidor).
import type { ThreadMessage } from './message-variant'

export type DeliveryStatus = 'progress' | 'sent' | 'delivered' | 'read'

/** `null` = não mostrar indicador (entrada, nota privada, falha, apagada). */
export function deliveryStatus(m: ThreadMessage, channel: string | null): DeliveryStatus | null {
  if (m.private || m.status === 'failed' || m.content_attributes.deleted) return null
  if (m.message_type !== 1 && m.message_type !== 3) return null
  if (m.status === 'progress') return 'progress'

  const hasSource = !!m.source_id
  switch (channel) {
    case 'Channel::Whatsapp':
      if (!hasSource) return 'progress'
      return m.status === 'read' || m.status === 'delivered' || m.status === 'sent'
        ? m.status
        : 'progress'
    case 'Channel::Telegram':
      // O Telegram só confirma o envio; sem source_id ainda está na fila
      return hasSource && m.status === 'sent' ? 'sent' : 'progress'
    default:
      return m.status === 'read' || m.status === 'delivered' || m.status === 'sent'
        ? m.status
        : 'progress'
  }
}
