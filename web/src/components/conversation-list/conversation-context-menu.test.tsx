import { QueryObserver } from '@tanstack/react-query'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import type { Conversation } from '../../api/types'
import { contactFixture, conversationFixture } from '../../test/conversation-fixtures'
import { accountFixture, profileFixture } from '../../test/fixtures'
import { server } from '../../test/server'
import { subscribeToAlerts } from '../toast/alert'
import { ConversationList } from './conversation-list'
import { parseSearch } from './search'
import { renderWithApp } from './test-utils'

const maria = (overrides: Partial<Conversation> = {}) =>
  conversationFixture({
    id: 7,
    meta: { ...conversationFixture().meta, sender: contactFixture({ name: 'Maria Cliente' }) },
    ...overrides,
  })

const agent = (id: number, name: string, availability_status: 'online' | 'busy' | 'offline') => ({
  id,
  account_id: 1,
  availability_status,
  auto_offline: false,
  confirmed: true,
  email: `${id}@example.com`,
  provider: 'email',
  available_name: name,
  name,
  role: 'agent',
  thumbnail: '',
})

let alerts: string[] = []
let unsubscribe = () => {}
beforeEach(() => {
  alerts = []
  unsubscribe = subscribeToAlerts((toast) => alerts.push(toast.message))
  vi.stubGlobal(
    'IntersectionObserver',
    class {
      observe() {}
      disconnect() {}
      unobserve() {}
    },
  )
})
afterEach(() => {
  unsubscribe()
  vi.unstubAllGlobals()
})

function respondWith(conversation: Conversation) {
  server.use(
    http.get('/api/v1/accounts/1/conversations', () =>
      HttpResponse.json({
        data: {
          meta: { mine_count: 0, assigned_count: 0, unassigned_count: 1, all_count: 1 },
          payload: [conversation],
        },
      }),
    ),
  )
}

async function openMenu(
  conversation = maria(),
  props: Partial<React.ComponentProps<typeof ConversationList>> = {},
) {
  respondWith(conversation)
  const user = userEvent.setup()
  const rendered = await renderWithApp(
    <ConversationList
      search={parseSearch({})}
      onSearchChange={() => {}}
      conversationHref={(c) => `/app/conversations/${c.id}?assignee_type=all`}
      {...props}
    />,
  )
  const card = await screen.findByRole('link', { name: /Maria Cliente/ })
  await user.pointer({ keys: '[MouseRight]', target: card })
  return { user, ...rendered }
}

test('o clique direito no card abre o menu com as ações da conversa aberta', async () => {
  await openMenu()
  for (const name of [
    'Mark as unread',
    'Mark as resolved',
    'Mark as pending',
    'Snooze',
    'Priority',
    'Assign label',
    'Assign agent',
    'Assign team',
    'Open in new tab',
    'Copy conversation link',
    'Delete conversation',
  ])
    expect(screen.getByRole('button', { name })).toBeInTheDocument()
  // a opção do status atual some (show(key)), e não lida vira "Mark as read"
  expect(screen.queryByRole('button', { name: 'Reopen conversation' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Mark as read' })).not.toBeInTheDocument()
})

test('conversa resolvida e com não lidas: Reopen e Mark as read, sem Snooze', async () => {
  await openMenu(maria({ status: 'resolved', unread_count: 2 }))
  expect(screen.getByRole('button', { name: 'Reopen conversation' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Mark as read' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Mark as resolved' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Snooze' })).not.toBeInTheDocument()
})

test('agente não vê a exclusão', async () => {
  respondWith(maria())
  const user = userEvent.setup()
  const { queryClient } = await renderWithApp(
    <ConversationList search={parseSearch({})} onSearchChange={() => {}} />,
  )
  queryClient.setQueryData(
    ['profile'],
    profileFixture({ accounts: [accountFixture({ role: 'agent', permissions: ['agent'] })] }),
  )
  await user.pointer({
    keys: '[MouseRight]',
    target: await screen.findByRole('link', { name: /Maria Cliente/ }),
  })
  expect(screen.getByRole('button', { name: 'Mark as resolved' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Delete conversation' })).not.toBeInTheDocument()
})

test('mudar o status chama o toggle_status, avisa e fecha o menu', async () => {
  let body: unknown
  server.use(
    http.post('/api/v1/accounts/1/conversations/7/toggle_status', async ({ request }) => {
      body = await request.json()
      return HttpResponse.json({ meta: {}, payload: { success: true, current_status: 'resolved' } })
    }),
  )
  const { user } = await openMenu()
  await user.click(screen.getByRole('button', { name: 'Mark as resolved' }))
  await waitFor(() => expect(body).toEqual({ status: 'resolved' }))
  await waitFor(() => expect(alerts).toContain('Conversation status changed'))
  expect(screen.queryByRole('button', { name: 'Mark as pending' })).not.toBeInTheDocument()
})

test('marcar como não lida chama o unread e volta para a lista', async () => {
  const unread = vi.fn()
  server.use(
    http.post('/api/v1/accounts/1/conversations/7/unread', () => {
      unread()
      return HttpResponse.json({})
    }),
  )
  const onCloseConversation = vi.fn()
  const { user } = await openMenu(maria(), { onCloseConversation })
  await user.click(screen.getByRole('button', { name: 'Mark as unread' }))
  await waitFor(() => expect(onCloseConversation).toHaveBeenCalled())
  expect(unread).toHaveBeenCalled()
})

test('prioridade: o submenu lista as outras e troca pela escolhida', async () => {
  let body: unknown
  server.use(
    http.post('/api/v1/accounts/1/conversations/7/toggle_priority', async ({ request }) => {
      body = await request.json()
      return new HttpResponse(null, { status: 200 })
    }),
  )
  const { user } = await openMenu(maria({ priority: 'low' }))
  await user.hover(screen.getByRole('button', { name: 'Priority' }))
  expect(screen.queryByRole('button', { name: 'Low' })).not.toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'High' }))
  await waitFor(() => expect(body).toEqual({ priority: 'high' }))
  await waitFor(() => expect(alerts).toContain('Changed priority of conversation id 7 to high'))
})

test('etiquetas: busca, adiciona a nova e remove a já aplicada, mantendo o menu aberto', async () => {
  server.use(
    http.get('/api/v1/accounts/1/labels', () =>
      HttpResponse.json({
        payload: [
          { id: 1, title: 'billing', color: '#ff0000', description: '', show_on_sidebar: true },
          { id: 2, title: 'vip', color: '#00ff00', description: '', show_on_sidebar: true },
        ],
      }),
    ),
  )
  const sent: unknown[] = []
  server.use(
    http.post('/api/v1/accounts/1/bulk_actions', async ({ request }) => {
      sent.push(await request.json())
      return new HttpResponse(null, { status: 200 })
    }),
  )
  const { user } = await openMenu(maria({ labels: ['vip'] }))
  await user.hover(screen.getByRole('button', { name: 'Assign label' }))
  await user.type(await screen.findByPlaceholderText('Search labels'), 'bil')
  expect(screen.queryByRole('button', { name: 'vip' })).not.toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'billing' }))
  await waitFor(() =>
    expect(sent).toEqual([{ type: 'Conversation', ids: [7], labels: { add: ['billing'] } }]),
  )
  expect(alerts).toContain('Assigned label #billing to conversation id 7')

  await user.clear(screen.getByPlaceholderText('Search labels'))
  await user.click(screen.getByRole('button', { name: 'vip' }))
  await waitFor(() => expect(sent).toHaveLength(2))
  expect(sent[1]).toEqual({ type: 'Conversation', ids: [7], labels: { remove: ['vip'] } })
  expect(alerts).toContain('Removed label #vip from conversation id 7')
})

test('agente: lista None e os atribuíveis da inbox por disponibilidade e atribui', async () => {
  const inboxIds: string[] = []
  server.use(
    http.get('/api/v1/accounts/1/assignable_agents', ({ request }) => {
      inboxIds.push(...new URL(request.url).searchParams.getAll('inbox_ids[]'))
      return HttpResponse.json({
        payload: [agent(3, 'Carla', 'offline'), agent(4, 'Bruno', 'online')],
      })
    }),
  )
  let body: unknown
  server.use(
    http.post('/api/v1/accounts/1/bulk_actions', async ({ request }) => {
      body = await request.json()
      return new HttpResponse(null, { status: 200 })
    }),
  )
  const { user } = await openMenu()
  await user.hover(screen.getByRole('button', { name: 'Assign agent' }))
  const [none, bruno, carla] = await Promise.all(
    ['None', 'Bruno', 'Carla'].map((name) => screen.findByRole('button', { name })),
  )
  const follows = (a: Element, b: Element) =>
    Boolean(a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING)
  // online antes de offline, com o "None" no topo
  expect(follows(none, bruno) && follows(bruno, carla)).toBe(true)
  expect(inboxIds).toEqual(['1'])
  await user.click(screen.getByRole('button', { name: 'Bruno' }))
  await waitFor(() =>
    expect(body).toEqual({ type: 'Conversation', ids: [7], fields: { assignee_id: 4 } }),
  )
  await waitFor(() => expect(alerts).toContain('Conversation id 7 assigned to "Bruno"'))
})

test('time: atribui o escolhido', async () => {
  server.use(
    http.get('/api/v1/accounts/1/teams', () =>
      HttpResponse.json([{ id: 5, name: 'Suporte', account_id: 1 }]),
    ),
  )
  let body: unknown
  server.use(
    http.post('/api/v1/accounts/1/conversations/7/assignments', async ({ request }) => {
      body = await request.json()
      return HttpResponse.json({})
    }),
  )
  const { user } = await openMenu()
  await user.hover(screen.getByRole('button', { name: 'Assign team' }))
  await user.click(await screen.findByRole('button', { name: 'Suporte' }))
  await waitFor(() => expect(body).toEqual({ team_id: 5 }))
  await waitFor(() => expect(alerts).toContain('Assigned team "Suporte" to conversation id 7'))
})

test('abrir em nova aba e copiar o link usam o endereço da conversa na visão atual', async () => {
  const open = vi.spyOn(window, 'open').mockReturnValue(null)
  const url = `${window.location.origin}/app/conversations/7?assignee_type=all`
  const { user } = await openMenu()
  await user.click(screen.getByRole('button', { name: 'Open in new tab' }))
  expect(open).toHaveBeenCalledWith(url, '_blank', 'noopener,noreferrer')
  expect(screen.queryByRole('button', { name: 'Open in new tab' })).not.toBeInTheDocument()

  await user.pointer({
    keys: '[MouseRight]',
    target: screen.getByRole('link', { name: /Maria Cliente/ }),
  })
  await user.click(screen.getByRole('button', { name: 'Copy conversation link' }))
  await waitFor(() => expect(alerts).toContain('Conversation link copied to clipboard'))
  expect(await navigator.clipboard.readText()).toBe(url)
})

test('a conversa excluída não é buscada de novo', async () => {
  const fetched = vi.fn()
  server.use(
    http.delete(
      '/api/v1/accounts/1/conversations/7',
      () => new HttpResponse(null, { status: 200 }),
    ),
    http.get('/api/v1/accounts/1/conversations/7', () => {
      fetched()
      return HttpResponse.json({}, { status: 404 })
    }),
  )
  const { user, queryClient } = await openMenu()
  // a conversa aberta à direita mantém a query dela viva
  const observer = new QueryObserver(queryClient, {
    queryKey: ['accounts', 1, 'conversations', 'detail', 7],
    queryFn: () => fetch('/api/v1/accounts/1/conversations/7').then((r) => r.json()),
    initialData: {},
    staleTime: Infinity,
  })
  const unsubscribeObserver = observer.subscribe(() => {})
  await user.click(screen.getByRole('button', { name: 'Delete conversation' }))
  await user.click(screen.getByRole('button', { name: 'Delete' }))
  await waitFor(() => expect(alerts).toContain('Conversation deleted successfully'))
  unsubscribeObserver()
  expect(fetched).not.toHaveBeenCalled()
})

test('excluir pede confirmação, apaga e volta para a lista', async () => {
  const deleted = vi.fn()
  server.use(
    http.delete('/api/v1/accounts/1/conversations/7', () => {
      deleted()
      return new HttpResponse(null, { status: 200 })
    }),
  )
  const onCloseConversation = vi.fn()
  const { user } = await openMenu(maria(), { onCloseConversation })
  await user.click(screen.getByRole('button', { name: 'Delete conversation' }))
  expect(screen.getByText('Delete conversation #7')).toBeInTheDocument()
  expect(screen.getByText('Are you sure you want to delete this conversation?')).toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Delete' }))
  await waitFor(() => expect(deleted).toHaveBeenCalled())
  await waitFor(() => expect(alerts).toContain('Conversation deleted successfully'))
  expect(onCloseConversation).toHaveBeenCalled()
})

// ContextMenu.vue fecha quando o foco sai do menu (focusout); Esc não é tratado
test('clique fora fecha o menu', async () => {
  const { user } = await openMenu()
  expect(screen.getByRole('button', { name: 'Mark as resolved' })).toBeInTheDocument()
  await user.click(document.body)
  expect(screen.queryByRole('button', { name: 'Mark as resolved' })).not.toBeInTheDocument()
})
