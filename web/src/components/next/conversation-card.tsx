// Port de components-next/Conversation/ConversationCard/ConversationCard.vue (+ CardMessagePreview e
// CardMessagePreviewWithMeta): o card compacto do histórico do contato e da busca.
// O selo de SLA do WithMeta é Enterprise: fica de fora.
import type { ReactNode } from 'react'

import type { Conversation, Inbox } from '../../api/types'
import { exactTimestamp, shortTimeAgo } from '../../shared/time-ago'
import { CardLabels, type AccountLabel } from '../conversation-list/card-labels'
import { lastMessage, PRIORITIES } from '../conversation-list/card-helpers'
import { MessagePreview } from '../conversation-list/message-preview'
import { Avatar } from './avatar'
import { ChannelIcon } from './channel-icon'
import { Icon } from './icon'

type Props = {
  conversation: Conversation
  inbox?: Inbox
  accountLabels: AccountLabel[]
  className?: string
  /** O pai decide a navegação (o original faz router.push para a conversa). */
  renderLink: (props: { className: string; children: ReactNode }) => ReactNode
}

function UnreadBadge({ count }: { count: number }) {
  if (count <= 0) return null
  return (
    <div className="inline-flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-n-brand">
      <span className="text-xs font-semibold text-white">{count}</span>
    </div>
  )
}

export function CompactConversationCard({
  conversation,
  inbox,
  accountLabels,
  className,
  renderLink,
}: Props) {
  const contact = conversation.meta.sender
  const assignee = conversation.meta.assignee
  const assigneeName = assignee?.name ?? assignee?.available_name
  const unread = conversation.unread_count
  const priority = conversation.priority ? PRIORITIES[conversation.priority] : null
  const hasVisibleLabels = accountLabels.some(({ title }) => conversation.labels.includes(title))
  const previewColor = unread > 0 ? 'text-n-slate-12' : 'text-n-slate-11'

  return (
    <>
      {renderLink({
        className: `flex w-full cursor-pointer gap-3 px-3 py-4 transition-all duration-300 ease-in-out ${className ?? ''}`,
        children: (
          <>
            <Avatar name={contact.name} size={24} />
            <div className="flex w-full min-w-0 flex-col gap-1">
              <div className="flex h-6 items-center justify-between gap-2">
                <h4 className="truncate text-base font-medium text-n-slate-12">{contact.name}</h4>
                <div className="flex items-center gap-2">
                  {priority && <Icon name={priority.icon} className="size-4 text-n-slate-5" />}
                  <div
                    title={inbox?.name}
                    className="flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-n-alpha-2"
                  >
                    <ChannelIcon
                      channel={inbox?.channel_type ?? conversation.meta.channel ?? ''}
                      className="size-3 flex-shrink-0 text-n-slate-11"
                    />
                  </div>
                  <span
                    title={exactTimestamp(conversation.timestamp)}
                    className="text-sm text-n-slate-10"
                  >
                    {shortTimeAgo(conversation.timestamp)}
                  </span>
                </div>
              </div>
              {hasVisibleLabels ? (
                <div className="flex w-full flex-col gap-1">
                  <div className="flex h-7 w-full items-center justify-between gap-2 py-1">
                    <MessagePreview
                      message={lastMessage(conversation)}
                      className={`!mx-0 min-w-0 flex-1 ${previewColor}`}
                    />
                    <UnreadBadge count={unread} />
                  </div>
                  <div className="grid h-7 grid-cols-[1fr_20px] items-center gap-2.5">
                    <div className="overflow-hidden">
                      <CardLabels labels={conversation.labels} accountLabels={accountLabels} />
                    </div>
                    {assigneeName && <Avatar name={assigneeName} size={20} />}
                  </div>
                </div>
              ) : (
                <div className="flex w-full items-end gap-2 pb-1">
                  <MessagePreview
                    message={lastMessage(conversation)}
                    className={`!mx-0 w-full ${previewColor}`}
                  />
                  <div className="flex flex-shrink-0 items-center gap-2 pb-2">
                    {assigneeName && <Avatar name={assigneeName} size={20} />}
                    <UnreadBadge count={unread} />
                  </div>
                </div>
              )}
            </div>
          </>
        ),
      })}
    </>
  )
}
