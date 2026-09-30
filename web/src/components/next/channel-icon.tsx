// Port de components-next/icon/ChannelIcon.vue (ícones Phosphor).
import { channelIconName } from './channel-icon-name'
import { Icon } from './icon'

type Props = {
  /** `telegram`, `whatsapp` ou o `channel_type` do Chatwoot (`Channel::Telegram`). */
  channel: string
  className?: string
}

export function ChannelIcon({ channel, className = 'size-4' }: Props) {
  return <Icon name={channelIconName(channel)} className={className} />
}
