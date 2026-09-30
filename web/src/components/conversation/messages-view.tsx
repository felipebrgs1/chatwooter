// Porta de components/widgets/conversation/MessagesView.vue: thread + caixa de resposta.
import type { Conversation } from '../../api/types'
import { useAccountId } from '../../api/use-account-id'
import { Composer } from './composer'
import { MessageList } from './message-list'
import { useMessages } from './use-messages'

export function MessagesView({ conversation }: { conversation: Conversation }) {
  const accountId = useAccountId()
  const thread = useMessages(accountId, conversation)

  return (
    <div className="m-0 flex h-full min-w-0 flex-grow flex-col justify-between">
      <MessageList
        messages={thread.messages}
        channel={conversation.meta.channel}
        hasOlder={!!thread.hasOlder}
        isLoadingOlder={thread.isLoadingOlder}
        onLoadOlder={() => void thread.loadOlder()}
        onRetry={(message) => void thread.retry(message)}
      />
      <Composer
        canReply={conversation.can_reply}
        onSend={(content, isPrivate) => void thread.send(content, isPrivate)}
      />
    </div>
  )
}
