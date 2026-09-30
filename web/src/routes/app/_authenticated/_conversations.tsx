import { createFileRoute, Link, Outlet, useMatch, useNavigate } from '@tanstack/react-router'
import { useCallback } from 'react'

import { ConversationList } from '../../../components/conversation-list/conversation-list'
import {
  parseSearch,
  parseUrlSearch,
  type ConversationsSearch,
} from '../../../components/conversation-list/search'
import { cx } from '../../../components/next/cx'

// Layout das conversas: a lista à esquerda (filtros na URL) e a conversa aberta, ou o vazio, à direita.
export const Route = createFileRoute('/app/_authenticated/_conversations')({
  validateSearch: parseUrlSearch,
  component: ConversationsLayout,
})

function ConversationsLayout() {
  // O TanStack junta aos validados os params brutos do pai: reparsear descarta o que não vale.
  const search = parseSearch(Route.useSearch())
  const navigate = useNavigate()
  const open = useMatch({
    from: '/app/_authenticated/_conversations/conversations/$conversationId',
    shouldThrow: false,
  })
  const activeId = open ? Number(open.params.conversationId) : undefined

  const onSearchChange = useCallback(
    (patch: Partial<ConversationsSearch>) =>
      void navigate({ to: '.', search: (prev) => parseUrlSearch({ ...prev, ...patch }) }),
    [navigate],
  )

  return (
    <div className="flex h-full min-w-0 flex-1">
      {/* no mobile a lista some enquanto há conversa aberta, como em ConversationView.vue */}
      <div className={cx('min-h-0', activeId ? 'hidden lg:flex' : 'flex', 'w-full sm:w-auto')}>
        <ConversationList
          search={search}
          activeId={activeId}
          onSearchChange={onSearchChange}
          renderCardLink={(conversation, { children, ...rest }) => (
            <Link
              to="/app/conversations/$conversationId"
              params={{ conversationId: String(conversation.id) }}
              search={search}
              {...rest}
            >
              {children}
            </Link>
          )}
        />
      </div>
      <div className={cx('min-w-0 flex-1 flex-col', activeId ? 'flex' : 'hidden lg:flex')}>
        <Outlet />
      </div>
    </div>
  )
}
