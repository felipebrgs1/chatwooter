// Porta de components-next/message/MessageStatus.vue (sem a animação do relógio).
import { useTranslation } from 'react-i18next'

import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import type { DeliveryStatus } from './delivery-status'

const icons: Record<DeliveryStatus, { icon: string; color: string; label: string }> = {
  progress: { icon: 'ph-clock', color: 'text-n-slate-10', label: 'CHAT_LIST.SENDING' },
  sent: { icon: 'ph-check', color: 'text-n-slate-10', label: 'CHAT_LIST.SENT' },
  delivered: { icon: 'ph-checks', color: 'text-n-slate-10', label: 'CHAT_LIST.DELIVERED' },
  // O original usa um hex azul claro; aqui, o token equivalente
  read: { icon: 'ph-checks', color: 'text-n-blue-9', label: 'CHAT_LIST.READ' },
}

export function MessageStatus({ status }: { status: DeliveryStatus }) {
  const { t } = useTranslation()
  const { icon, color, label } = icons[status]
  return (
    <span aria-label={t(label)} title={t(label)} role="img" className="inline-flex">
      <Icon name={icon} className={cx('size-3.5', color)} />
    </span>
  )
}
