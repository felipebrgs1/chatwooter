// Port de components-next/Conversation/ConversationCard/ConversationCardExpanded.vue: uma linha por conversa
// no layout expandido, com CardPriorityIcon, CardStatusIcon, CardAvatar, CardContent e CardLabelsV5 inline.
import type { MouseEvent, ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import type { Conversation } from '../../api/types'
import { Avatar } from '../next/avatar'
import { ChannelIcon } from '../next/channel-icon'
import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { CardLabels, type AccountLabel } from './card-labels'
import { lastMessage, PRIORITIES, STATUS_ICONS } from './card-helpers'
import type { CardLinkProps } from './conversation-card'
import { MessagePreview } from './message-preview'
import { exactTimestamp, shortTimeAgo } from '../../shared/time-ago'
import { useTimeAgo } from './use-time-ago'

type Props = {
  conversation: Conversation
  href: string
  active?: boolean
  accountLabels?: AccountLabel[]
  /** Nome da inbox; sem ele a coluna de inbox não aparece (showInboxName do original). */
  inboxName?: string
  now?: Date
  renderLink?: (props: CardLinkProps) => ReactNode
  onContextMenu?: (event: MouseEvent) => void
}

export function ConversationCardExpanded({
  conversation,
  href,
  active = false,
  accountLabels,
  inboxName,
  now: referenceNow,
  renderLink,
  onContextMenu,
}: Props) {
  const { t } = useTranslation()
  const currentNow = useTimeAgo(conversation.last_activity_at, conversation.id)
  const now = referenceNow ?? currentNow
  const contact = conversation.meta.sender
  const unread = conversation.unread_count
  // showAssigneeForExpandedCard é sempre verdadeiro no card expandido
  const assigneeName = conversation.meta.assignee?.available_name
  const priority = conversation.priority ? PRIORITIES[conversation.priority] : null
  const status = STATUS_ICONS[conversation.status]
  const hasLabels = conversation.labels.length > 0

  const linkProps: CardLinkProps = {
    'aria-current': active ? 'page' : undefined,
    onContextMenu,
    className: cx(
      'conversation group relative grid h-12 cursor-pointer items-center gap-4 border-b border-n-slate-3 px-3 before:pointer-events-none before:absolute before:inset-x-0 before:-top-px before:h-px before:bg-n-surface-1 before:content-none hover:z-[1] hover:border-n-surface-1 hover:before:content-[""]',
      active
        ? 'active animate-card-select !border-n-surface-1 bg-n-alpha-1 dark:bg-n-alpha-3'
        : 'hover:bg-n-alpha-1',
      hasLabels
        ? 'grid-cols-[minmax(0,2fr)_minmax(0,1fr)]'
        : 'grid-cols-[minmax(0,2fr)_max-content]',
    ),
    children: (
      <>
        <div className="flex min-w-0 flex-1 items-center gap-2">
          {/* Checkbox de seleção: entra com as ações em massa */}
          <div className="h-3 w-px flex-shrink-0 bg-n-slate-6" />
          <div className="flex w-4 flex-shrink-0 items-center justify-center">
            <span
              title={t(priority?.key ?? 'CONVERSATION.PRIORITY.OPTIONS.NONE')}
              className="inline-flex"
            >
              <Icon
                name={priority?.icon ?? 'ph-cell-signal-none'}
                className="size-4 text-n-slate-5"
              />
            </span>
          </div>
          <div className="flex w-4 flex-shrink-0 items-center justify-center">
            {assigneeName ? (
              <span title={assigneeName} className="inline-flex">
                <Avatar name={assigneeName} size={14} />
              </span>
            ) : (
              <Icon name="ph-user-circle" className="size-4 text-n-slate-7" />
            )}
          </div>
          <div className="flex w-4 flex-shrink-0 items-center justify-center">
            <span title={conversation.status} className="inline-flex">
              <Icon
                name={status?.icon ?? 'ph-circle-dashed'}
                className={cx('size-4 flex-shrink-0', status?.color ?? 'text-n-slate-10')}
              />
            </span>
          </div>
          <div className="h-3 w-px flex-shrink-0 bg-n-slate-6" />
          {inboxName && (
            <>
              <div className="w-20 flex-shrink-0">
                <div title={inboxName} className="flex min-w-0 items-center gap-0.5">
                  {conversation.meta.channel && (
                    <ChannelIcon
                      channel={conversation.meta.channel}
                      className="size-4 flex-shrink-0 text-n-slate-11"
                    />
                  )}
                  <span className="truncate text-body-main text-n-slate-11">{inboxName}</span>
                </div>
              </div>
              <div className="h-3 w-px flex-shrink-0 bg-n-slate-6" />
            </>
          )}
          <div
            title={String(conversation.id)}
            className="flex h-6 w-full min-w-0 max-w-20 flex-shrink-0 items-center gap-1"
          >
            <Icon name="ph-hash" className="size-3.5 flex-shrink-0 text-n-slate-10" />
            <span className="truncate text-body-main text-n-slate-11">{conversation.id}</span>
          </div>
          <div className="relative flex flex-shrink-0 items-center">
            <Avatar name={contact.name} size={24} />
          </div>
          <h4 className="my-0 w-32 flex-shrink-0 truncate text-heading-3 font-medium capitalize text-n-slate-12">
            {contact.name}
          </h4>
          <div className="grid min-w-0 flex-1 grid-cols-[1fr_auto] items-center gap-1.5">
            <MessagePreview
              message={lastMessage(conversation)}
              className={cx(
                '!mx-0 text-body-main',
                unread > 0 ? 'text-n-slate-12' : 'text-n-slate-11',
              )}
            />
            {unread > 0 && (
              <span
                data-testid="unread"
                className="inline-grid h-4 w-fit min-w-4 max-w-5 flex-shrink-0 place-items-center rounded-full bg-n-teal-9 px-1 text-xxs font-medium leading-3 text-white"
              >
                {unread > 9 ? t('CHAT_LIST.UNREAD_COUNT_OVERFLOW') : unread}
              </span>
            )}
          </div>
        </div>
        <div className="flex flex-shrink-0 items-center justify-end gap-1.5">
          {hasLabels && (
            <div className="w-full min-w-0">
              <CardLabels
                labels={conversation.labels}
                accountLabels={accountLabels}
                disableToggle
                className="my-0 justify-end [&>div]:justify-end"
              />
            </div>
          )}
          {/* SLACardLabel depende das políticas de SLA (Enterprise): fora do v1 */}
          <div className="w-[4.375rem] flex-shrink-0 text-end">
            <span
              title={`${t('CHAT_LIST.CHAT_TIME_STAMP.CREATED.OLDEST')} ${exactTimestamp(conversation.created_at)}\n${t('CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.NOT_ACTIVE')} ${exactTimestamp(conversation.last_activity_at)}`}
              className="ml-auto !text-xs font-[440] leading-4 text-n-slate-11"
            >
              {shortTimeAgo(conversation.created_at, now)} •{' '}
              {shortTimeAgo(conversation.last_activity_at, now)}
            </span>
          </div>
        </div>
      </>
    ),
  }

  const render = renderLink ?? ((props: CardLinkProps) => <a href={href} {...props} />)
  return <>{render(linkProps)}</>
}
