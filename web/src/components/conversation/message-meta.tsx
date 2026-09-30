// Porta de components-next/message/MessageMeta.vue: horário, cadeado de nota privada e status de entrega.
import { useTranslation } from 'react-i18next'

import { Icon } from '../next/icon'
import type { DeliveryStatus } from './delivery-status'
import { messageTimestamp } from './message-time'
import { MessageStatus } from './message-status'

type Props = { createdAt: number; isPrivate: boolean; status: DeliveryStatus | null }

export function MessageMeta({ createdAt, isPrivate, status }: Props) {
  const { i18n } = useTranslation()
  return (
    <div className="flex items-center gap-1.5 text-xs">
      <time className="inline" dateTime={new Date(createdAt * 1000).toISOString()}>
        {messageTimestamp(createdAt, i18n.language)}
      </time>
      {isPrivate && (
        <span data-testid="private-lock" className="inline-flex">
          <Icon name="ph-lock-key" className="size-3" />
        </span>
      )}
      {status && <MessageStatus status={status} />}
    </div>
  )
}
