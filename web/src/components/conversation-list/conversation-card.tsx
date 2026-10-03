// Port de components/widgets/conversation/ConversationCard.vue (layout condensado).
import type { MouseEvent, ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import type { Conversation } from '../../api/types'
import { Avatar } from '../next/avatar'
import { ChannelIcon } from '../next/channel-icon'
import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { CardLabels, type AccountLabel } from './card-labels'
import { lastMessage, PRIORITIES } from './card-helpers'
import { MessagePreview } from './message-preview'
import { exactTimestamp, shortTimeAgo } from '../../shared/time-ago'
import { useTimeAgo } from './use-time-ago'

export type CardLinkProps = {
  className: string
  children: ReactNode
  'aria-current'?: 'page'
  onContextMenu?: (event: MouseEvent) => void
}

type Props = {
  conversation: Conversation
  href: string
  active?: boolean
  accountLabels?: AccountLabel[]
  /** Nome da inbox (o JSON da conversa só traz o id): sem ele o cabeçalho de inbox não aparece. */
  inboxName?: string
  showAssignee?: boolean
  /** Instante de referência opcional para previews determinísticos. */
  now?: Date
  /** O pai injeta o <Link> do roteador. */
  renderLink?: (props: CardLinkProps) => ReactNode
  onContextMenu?: (event: MouseEvent) => void
}

export function ConversationCard({
  conversation,
  href,
  active = false,
  accountLabels,
  inboxName,
  showAssignee = false,
  now: referenceNow,
  renderLink,
  onContextMenu,
}: Props) {
  const { t } = useTranslation()
  const currentNow = useTimeAgo(conversation.last_activity_at, conversation.id)
  const now = referenceNow ?? currentNow
  const contact = conversation.meta.sender
  const unread = conversation.unread_count
  const assigneeName = conversation.meta.assignee?.available_name
  const priority = conversation.priority ? PRIORITIES[conversation.priority] : null
  const showMeta =
    Boolean(inboxName) || (showAssignee && Boolean(assigneeName)) || priority !== null
  const inboxHeader = Boolean(inboxName)

  const linkProps: CardLinkProps = {
    'aria-current': active ? 'page' : undefined,
    onContextMenu,
    className: cx(
      'conversation group relative flex w-auto max-w-full flex-shrink-0 flex-grow-0 cursor-pointer items-start border-b border-n-slate-3 px-3 py-0 before:pointer-events-none before:absolute before:inset-x-0 before:-top-px before:h-px before:bg-n-surface-1 before:content-none hover:z-[1] hover:border-n-surface-1 hover:bg-n-alpha-1 hover:before:content-[""] dark:hover:bg-n-alpha-3',
      active && 'active animate-card-select border-n-surface-1 bg-n-background',
    ),
    children: (
      <>
        <div className="group/avatar relative">
          <Avatar name={contact.name} size={32} className={inboxHeader ? 'mt-8' : 'mt-4'} />
        </div>
        <div className="min-w-0 flex-1 px-0 py-3">
          {showMeta && (
            <div className="ml-2 flex min-w-0 items-center gap-1">
              {inboxName && (
                <div title={inboxName} className="flex min-w-0 flex-1 items-center gap-0.5">
                  {conversation.meta.channel && (
                    <ChannelIcon
                      channel={conversation.meta.channel}
                      className="size-4 flex-shrink-0 text-n-slate-11"
                    />
                  )}
                  <span className="text-label-small truncate text-n-slate-11">{inboxName}</span>
                </div>
              )}
              <div
                className={cx(
                  'flex flex-shrink-0 items-baseline gap-2',
                  !inboxHeader && 'flex-1 justify-between',
                )}
              >
                {showAssignee && assigneeName && (
                  <span className="inline-flex items-center gap-px truncate px-0 py-0.5 text-xs font-medium leading-3 text-n-slate-11">
                    <Icon name="ph-user" className="size-3 flex-shrink-0 text-n-slate-11" />
                    <span className="truncate">{assigneeName}</span>
                  </span>
                )}
                {priority && (
                  <span title={t(priority.key)} className="flex-shrink-0">
                    <Icon name={priority.icon} className="size-3.5 text-n-slate-5" />
                  </span>
                )}
              </div>
            </div>
          )}
          <h4
            className={cx(
              'conversation--user mx-2 my-0 min-w-0 flex-1 overflow-hidden text-ellipsis whitespace-nowrap pr-16 pt-0.5 text-sm capitalize text-n-slate-12',
              unread > 0 ? 'font-semibold' : 'font-medium',
            )}
          >
            {contact.name}
          </h4>
          <MessagePreview
            message={lastMessage(conversation)}
            className={cx(unread > 0 ? 'pr-4 font-medium text-n-slate-12' : 'text-n-slate-11')}
          />
          <CardLabels
            labels={conversation.labels}
            accountLabels={accountLabels}
            className="mx-2 mb-0 mt-0.5"
          />
          <div className={cx('absolute right-3 flex flex-col', showMeta ? 'top-8' : 'top-4')}>
            <span className="ml-auto text-xxs font-normal leading-4">
              <div
                title={`${t('CHAT_LIST.CHAT_TIME_STAMP.CREATED.OLDEST')} ${exactTimestamp(conversation.created_at)}\n${t('CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.NOT_ACTIVE')} ${exactTimestamp(conversation.last_activity_at)}`}
                className="ml-auto text-xxs leading-4 text-n-slate-10 hover:text-n-slate-11"
              >
                <span>
                  {shortTimeAgo(conversation.created_at, now)} •{' '}
                  {shortTimeAgo(conversation.last_activity_at, now)}
                </span>
              </div>
            </span>
            {unread > 0 && (
              <span
                data-testid="unread"
                className="ml-auto mt-1 inline-grid h-4 w-fit min-w-4 max-w-5 flex-shrink-0 place-items-center rounded-full bg-n-teal-9 px-1 text-xxs font-medium leading-3 text-white"
              >
                {unread > 9 ? t('CHAT_LIST.UNREAD_COUNT_OVERFLOW') : unread}
              </span>
            )}
          </div>
        </div>
      </>
    ),
  }

  const render = renderLink ?? ((props: CardLinkProps) => <a href={href} {...props} />)
  return <>{render(linkProps)}</>
}
