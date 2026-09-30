import type { Conversation, ConversationPriority, Message } from '../../api/types'

// CardPriorityIcon.vue: ícone e chave i18n por prioridade (o enum do Rails chega como nome).
export const PRIORITIES: Record<
  NonNullable<ConversationPriority>,
  { icon: string; key: string }
> = {
  low: { icon: 'ph-cell-signal-low', key: 'CONVERSATION.PRIORITY.OPTIONS.LOW' },
  medium: { icon: 'ph-cell-signal-medium', key: 'CONVERSATION.PRIORITY.OPTIONS.MEDIUM' },
  high: { icon: 'ph-cell-signal-high', key: 'CONVERSATION.PRIORITY.OPTIONS.HIGH' },
  urgent: { icon: 'ph-cell-signal-full', key: 'CONVERSATION.PRIORITY.OPTIONS.URGENT' },
}

/** getLastMessage (conversationHelper.js): a última que não é atividade; senão a última que houver. */
export function lastMessage(conversation: Conversation): Message | null {
  return conversation.last_non_activity_message ?? conversation.messages.at(-1) ?? null
}
