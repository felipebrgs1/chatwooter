// Porta de components-next/message/Message.vue: escolhe o balão, a orientação e mostra avatar e erro de envio.
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Avatar } from '../next/avatar'
import { cx } from '../next/cx'
import { AttachmentView } from './attachment-view'
import { Bubble } from './bubble'
import { deliveryStatus } from './delivery-status'
import { FormattedContent } from './formatted-content'
import { MessageError } from './message-error'
import { orientationOf, variantOf, type ThreadMessage } from './message-variant'

const DAY = 24 * 60 * 60

type Props = {
  message: ThreadMessage
  /** channel_type da inbox (`Channel::Telegram`): define como o status de entrega aparece */
  channel: string | null
  groupWithNext?: boolean
  continuesGroup?: boolean
  onRetry?: (message: ThreadMessage) => void
}

export function Message({
  message,
  channel,
  groupWithNext = false,
  continuesGroup = false,
  onRetry,
}: Props) {
  const { t } = useTranslation()
  // Fixado na montagem: o render não pode depender do relógio
  const [mountedAt] = useState(() => Date.now() / 1000)
  const variant = variantOf(message)
  const orientation = orientationOf(message)
  const attachments = message.attachments ?? []
  const externalError = message.content_attributes.external_error as string | undefined
  const grouped = message.status === 'failed' ? false : groupWithNext
  const showAvatar = !grouped && orientation === 'right'

  const common = {
    variant,
    orientation,
    createdAt: message.created_at,
    status: deliveryStatus(message, channel),
    groupWithNext: grouped,
    continuesGroup,
  }

  // Uma mídia sozinha (sem texto) ganha um balão próprio; com texto, os anexos entram no balão de texto.
  const single = attachments.length === 1 && !message.content ? attachments[0] : null
  let body
  if (variant === 'activity') {
    body = (
      <Bubble
        {...common}
        name="activity"
        className="flex min-w-0 items-center gap-2 !rounded-xl px-3 py-1"
      >
        <span title={message.content ?? ''}>{message.content}</span>
      </Bubble>
    )
  } else if (single) {
    const audio = single.file_type === 'audio'
    body = (
      <Bubble
        {...common}
        name={single.file_type}
        className={cx(
          audio ? 'bg-transparent' : 'overflow-hidden',
          !audio && single.file_type !== 'file' && 'p-3',
        )}
      >
        <AttachmentView attachment={single} />
      </Bubble>
    )
  } else {
    body = (
      <Bubble {...common} name="text" className="px-4 py-3">
        {message.content && <FormattedContent content={message.content} />}
        {attachments.length > 0 && (
          <div className={cx('flex flex-col gap-2', message.content && 'mt-2')}>
            {attachments.map((a) => (
              <AttachmentView key={a.id} attachment={a} />
            ))}
          </div>
        )}
      </Bubble>
    )
  }

  const justify = { left: 'justify-start', right: 'justify-end', center: 'justify-center' }[
    orientation
  ]

  return (
    <div
      id={`message${message.id}`}
      data-message-id={message.id}
      className={cx('message-bubble-container mb-2 flex w-full', justify)}
    >
      {variant === 'activity' ? (
        body
      ) : (
        <div
          className={cx(
            'gap-x-2',
            orientation === 'right' ? 'grid grid-cols-[1fr_24px]' : 'grid grid-cols-1',
            externalError && 'gap-y-2',
          )}
          style={{
            gridTemplateAreas:
              orientation === 'right' ? '"bubble avatar" "meta spacer"' : '"bubble" "meta"',
          }}
        >
          {showAvatar && (
            <div
              className="flex items-end [grid-area:avatar]"
              title={
                message.sender?.name
                  ? `${t('CONVERSATION.SENT_BY')} ${message.sender.name}`
                  : undefined
              }
            >
              <Avatar name={message.sender?.name ?? t('CONVERSATION.BOT')} size={24} />
            </div>
          )}
          <div
            className={cx(
              'flex min-w-0 [grid-area:bubble]',
              orientation === 'right' ? 'ml-8 justify-end' : 'mr-8',
            )}
          >
            {body}
          </div>
          {externalError && (
            <MessageError
              className={cx(
                '[grid-area:meta]',
                orientation === 'right' ? 'justify-end' : 'justify-start',
              )}
              error={externalError}
              orientation={orientation === 'left' ? 'left' : 'right'}
              canRetry={
                message.created_at > mountedAt - DAY &&
                (message.content !== null || attachments.length > 0)
              }
              onRetry={() => onRetry?.(message)}
            />
          )}
        </div>
      )}
    </div>
  )
}
