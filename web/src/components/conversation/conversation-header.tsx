// Porta de components/widgets/conversation/ConversationHeader.vue (sem SLA, chamadas nem menu "mais ações").
// Snooze no cabeçalho entra com o menu de status.
import { useTranslation } from 'react-i18next'

import type { Conversation, ConversationStatus, Inbox } from '../../api/types'
import { Avatar } from '../next/avatar'
import { ChannelIcon } from '../next/channel-icon'
import { showAlert } from '../toast/alert'
import { BackButton } from './back-button'
import { ResolveAction } from './resolve-action'

type Props = {
  conversation: Conversation
  statusLoading?: boolean
  onStatusChange: (status: ConversationStatus) => void
  /** Layout expandido: a lista está escondida e o cabeçalho leva de volta a ela. */
  showBackButton?: boolean
  /** Inbox da conversa; só vem quando a conta tem mais de uma (hasMultipleInboxes). */
  inbox?: Inbox
}

export function ConversationHeader({
  conversation,
  statusLoading,
  onStatusChange,
  showBackButton = false,
  inbox,
}: Props) {
  const { t } = useTranslation()
  const contact = conversation.meta.sender

  async function copyId() {
    try {
      await navigator.clipboard.writeText(String(conversation.id))
      showAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'))
    } catch {
      // sem permissão de área de transferência: nada a fazer
    }
  }

  return (
    <div className="flex h-24 w-full min-w-0 flex-1 flex-col items-center justify-between gap-3 border-b border-b-n-weak px-3 pb-2 !pt-2 xl:h-12 xl:flex-row">
      <div className="flex w-full min-w-0 max-w-full items-center justify-start xl:w-auto xl:flex-1">
        {showBackButton && <BackButton className="me-2" />}
        <Avatar name={contact.name} size={32} />
        <div className="ms-2 flex min-w-0 flex-col items-start overflow-hidden">
          <div className="m-0 flex max-w-full flex-row items-center gap-1 p-0">
            <span className="truncate text-sm font-medium leading-tight text-n-slate-12">
              {contact.name}
            </span>
          </div>
          <div className="conversation--header--actions flex items-center gap-1 overflow-hidden text-ellipsis whitespace-nowrap text-xs text-n-slate-11">
            <button
              type="button"
              onClick={copyId}
              className="truncate !p-0 text-label-small text-n-slate-11 hover:text-n-slate-12"
            >
              {`#${conversation.id}`}
            </button>
            {inbox && (
              <>
                <span>•</span>
                {/* InboxName.vue */}
                <div title={inbox.name} className="!mx-0 flex min-w-0 items-center gap-0.5">
                  <ChannelIcon
                    channel={inbox.channel_type}
                    className="size-4 flex-shrink-0 text-n-slate-11"
                  />
                  <span className="truncate text-label-small text-n-slate-11">{inbox.name}</span>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
      <div className="header-actions-wrap flex w-full flex-shrink-0 flex-row items-center justify-start gap-2 xl:w-auto xl:justify-end">
        <ResolveAction
          status={conversation.status}
          isLoading={statusLoading}
          onChange={onStatusChange}
        />
      </div>
    </div>
  )
}
