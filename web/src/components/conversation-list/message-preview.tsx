// Port de components/widgets/conversation/MessagePreview.vue (+ o ramo "No Messages" do card).
import { useTranslation } from 'react-i18next'

import type { FileType, Message } from '../../api/types'
import { cx } from '../next/cx'
import { Icon } from '../next/icon'

const ATTACHMENT_ICONS: Partial<Record<FileType | 'ig_reel' | 'embed', string>> = {
  image: 'ph-image',
  audio: 'ph-headphones',
  video: 'ph-video-camera',
  file: 'ph-file',
  location: 'ph-map-pin',
  fallback: 'ph-link',
}

function typeOf(message: Message): { kind: string; icon: string } | null {
  if (message.private) return { kind: 'private', icon: 'ph-lock-simple' }
  if (message.message_type === 1) return { kind: 'outgoing', icon: 'ph-arrow-bend-up-left' }
  if (message.message_type === 2) return { kind: 'activity', icon: 'ph-info' }
  return null
}

type Props = { message: Message | null; className?: string }

export function MessagePreview({ message, className }: Props) {
  const { t } = useTranslation()

  if (!message) {
    return (
      <p
        className={cx(
          'mx-2 my-0 h-6 min-w-0 flex-1 overflow-hidden text-ellipsis whitespace-nowrap text-sm leading-6 text-n-slate-11',
          className,
        )}
      >
        <Icon name="ph-info" className="-mt-0.5 inline-block size-4 align-middle text-n-slate-10" />
        <span className="mx-0.5">{t('CHAT_LIST.NO_MESSAGES')}</span>
      </p>
    )
  }

  const type = typeOf(message)
  const attachment = message.attachments?.[0]
  const attachmentIcon = attachment && ATTACHMENT_ICONS[attachment.file_type]

  return (
    <div
      className={cx(
        'mx-2 my-0 h-6 min-w-0 flex-1 overflow-hidden text-ellipsis whitespace-nowrap text-sm leading-6',
        className,
      )}
    >
      {type && (
        <span data-type={type.kind} className="inline-block">
          <Icon
            name={type.icon}
            className="-mt-0.5 inline-block size-4 align-middle text-n-slate-11"
          />
        </span>
      )}
      {message.content?.trim() ? (
        <span>{message.content}</span>
      ) : attachment ? (
        <span>
          {attachmentIcon && (
            <Icon
              name={attachmentIcon}
              className="-mt-0.5 inline-block size-4 align-middle text-n-slate-11"
            />
          )}
          {t(`CHAT_LIST.ATTACHMENTS.${attachment.file_type}.CONTENT`)}
        </span>
      ) : (
        <span>{t('CHAT_LIST.NO_CONTENT')}</span>
      )}
    </div>
  )
}
