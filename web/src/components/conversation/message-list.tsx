// Lista de mensagens da conversa: agrupa consecutivas (MessageList.vue) e cuida da rolagem.
import { useRef } from 'react'

import { Message } from './message'
import { groupsWithNext, type ThreadMessage } from './message-variant'
import { useThreadScroll } from './use-thread-scroll'

type Props = {
  messages: ThreadMessage[]
  channel: string | null
  hasOlder: boolean
  isLoadingOlder: boolean
  onLoadOlder: () => void
  onRetry: (message: ThreadMessage) => void
}

export function MessageList({
  messages,
  channel,
  hasOlder,
  isLoadingOlder,
  onLoadOlder,
  onRetry,
}: Props) {
  const ref = useRef<HTMLDivElement>(null)
  const onScroll = useThreadScroll(ref, messages, { hasOlder, isLoadingOlder, onLoadOlder })

  return (
    <div
      ref={ref}
      onScroll={onScroll}
      data-testid="message-list"
      className="conversation-panel relative m-0 flex h-full flex-shrink flex-grow basis-px flex-col overflow-y-auto px-4 pb-4 pt-4"
    >
      {messages.map((message, index) => (
        <Message
          key={message.echo_id && message.id < 0 ? `pending-${message.echo_id}` : message.id}
          message={message}
          channel={channel}
          groupWithNext={groupsWithNext(message, messages[index + 1])}
          continuesGroup={index > 0 && groupsWithNext(messages[index - 1], message)}
          onRetry={onRetry}
        />
      ))}
    </div>
  )
}
