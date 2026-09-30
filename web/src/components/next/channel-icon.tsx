// Port de components-next/icon/ChannelIcon.vue (ícones Phosphor).
import { Icon } from './icon'

const icons: Record<string, string> = { telegram: 'ph-telegram-logo', whatsapp: 'ph-whatsapp-logo' }

type Props = {
  /** `telegram`, `whatsapp` ou o `channel_type` do Chatwoot (`Channel::Telegram`). */
  channel: string
  className?: string
}

export function ChannelIcon({ channel, className = 'size-4' }: Props) {
  const key = channel.replace(/^Channel::/, '').toLowerCase()
  return <Icon name={icons[key] ?? 'ph-tray'} className={className} />
}
