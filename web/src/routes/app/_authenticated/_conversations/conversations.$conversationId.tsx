import { createFileRoute } from '@tanstack/react-router'

import { ConversationView } from '../../../../components/conversation/conversation-view'

// $conversationId é o display_id (o "#123" visível), como nas rotas da API
export const Route = createFileRoute(
  '/app/_authenticated/_conversations/conversations/$conversationId',
)({
  component: OpenConversation,
})

function OpenConversation() {
  const { conversationId } = Route.useParams()
  return <ConversationView conversationId={Number(conversationId)} />
}
