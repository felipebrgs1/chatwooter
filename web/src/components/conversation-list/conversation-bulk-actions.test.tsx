import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import type { Conversation } from '../../api/types'
import { contactFixture, conversationFixture } from '../../test/conversation-fixtures'
import { server } from '../../test/server'
import { subscribeToAlerts } from '../toast/alert'
import { ConversationList } from './conversation-list'
import { parseSearch, type ConversationsSearch } from './search'
import { renderWithApp } from './test-utils'

const conv = (id: number, name: string, overrides: Partial<Conversation> = {}) =>
  conversationFixture({
    id,
    inbox_id: id,
    meta: { ...conversationFixture().meta, sender: contactFixture({ id, name }) },
    ...overrides,
  })

const ana = conv(1, 'Ana Souza', { labels: ['vip'] })
const bruno = conv(2, 'Bruno Lima')

let alerts: string[] = []
let unsubscribe = () => {}
let bulkBodies: unknown[] = []
beforeEach(() => {
  alerts = []
  bulkBodies = []
  unsubscribe = subscribeToAlerts((toast) => alerts.push(toast.message))
  vi.stubGlobal(
    'IntersectionObserver',
    class {
      observe() {}
      disconnect() {}
      unobserve() {}
    },
  )
  server.use(
    http.get('/api/v1/accounts/1/conversations', () =>
      HttpResponse.json({
        data: {
          meta: { mine_count: 0, assigned_count: 0, unassigned_count: 2, all_count: 2 },
          payload: [ana, bruno],
        },
      }),
    ),
    http.post('/api/v1/accounts/1/bulk_actions', async ({ request }) => {
      bulkBodies.push(await request.json())
      return new HttpResponse(null, { status: 200 })
    }),
    http.get('/api/v1/accounts/1/labels', () =>
      HttpResponse.json({
        payload: [
          { id: 1, title: 'billing', color: '#ff0000', description: '', show_on_sidebar: true },
          { id: 2, title: 'vip', color: '#00ff00', description: '', show_on_sidebar: true },
        ],
      }),
    ),
  )
})
afterEach(() => {
  unsubscribe()
  vi.unstubAllGlobals()
})

async function setup(search: Partial<ConversationsSearch> = {}) {
  const user = userEvent.setup()
  const onSearchChange = vi.fn()
  const rendered = await renderWithApp(
    <ConversationList search={{ ...parseSearch({}), ...search }} onSearchChange={onSearchChange} />,
  )
  await screen.findByRole('link', { name: /Ana Souza/ })
  return { user, onSearchChange, ...rendered }
}

const checkboxOf = (name: RegExp) =>
  within(screen.getByRole('link', { name })).getByRole('checkbox')

async function selectBoth(user: ReturnType<typeof userEvent.setup>) {
  await user.click(checkboxOf(/Ana Souza/))
  await user.click(checkboxOf(/Bruno Lima/))
}

test('marcar o card seleciona a conversa sem abri-la e mostra a barra', async () => {
  const { user } = await setup()
  expect(screen.queryByText('1 selected')).not.toBeInTheDocument()
  await user.click(checkboxOf(/Ana Souza/))
  expect(checkboxOf(/Ana Souza/)).toHaveAttribute('aria-checked', 'true')
  expect(screen.getByText('1 selected')).toBeInTheDocument()

  await user.click(checkboxOf(/Ana Souza/))
  expect(screen.queryByText('1 selected')).not.toBeInTheDocument()
})

test('selecionar todas avisa que só a página visível entra; Clear limpa', async () => {
  const { user } = await setup()
  await user.click(checkboxOf(/Ana Souza/))
  const all = screen.getByRole('checkbox', { name: '1 selected' })
  expect(all).toHaveAttribute('aria-checked', 'mixed')
  await user.click(all)
  expect(screen.getByText('2 selected')).toBeInTheDocument()
  expect(
    screen.getByText('Conversations visible on this page are only selected.'),
  ).toBeInTheDocument()

  await user.click(screen.getByRole('button', { name: 'Clear' }))
  expect(screen.queryByText('2 selected')).not.toBeInTheDocument()
})

test('trocar de aba limpa a seleção', async () => {
  const { user, rerender } = await setup()
  await user.click(checkboxOf(/Ana Souza/))
  rerender(
    <ConversationList
      search={{ ...parseSearch({}), assignee_type: 'all' }}
      onSearchChange={() => {}}
    />,
  )
  await waitFor(() => expect(screen.queryByText('1 selected')).not.toBeInTheDocument())
})

test('mudar o status resolve as selecionadas e limpa a seleção', async () => {
  const { user } = await setup()
  await selectBoth(user)
  await user.click(screen.getByRole('button', { name: 'Change status' }))
  // todas abertas: Reopen não aparece
  expect(screen.queryByRole('button', { name: 'Reopen' })).not.toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Resolve' }))
  await waitFor(() =>
    expect(bulkBodies).toEqual([
      { type: 'Conversation', ids: [1, 2], fields: { status: 'resolved' } },
    ]),
  )
  await waitFor(() => expect(alerts).toContain('Conversation status updated successfully.'))
  expect(screen.queryByText('2 selected')).not.toBeInTheDocument()
})

test('etiquetas: aplica as escolhidas e remove só entre as já aplicadas', async () => {
  const { user } = await setup()
  await selectBoth(user)
  await user.click(screen.getByRole('button', { name: 'Assign labels' }))
  await user.click(screen.getByRole('button', { name: 'billing' }))
  await user.click(screen.getByRole('button', { name: 'vip' }))
  await user.click(screen.getByRole('button', { name: 'Assign selected labels' }))
  await waitFor(() =>
    expect(bulkBodies[0]).toEqual({
      type: 'Conversation',
      ids: [1, 2],
      labels: { add: ['billing', 'vip'] },
    }),
  )
  await waitFor(() => expect(alerts).toContain('Labels assigned successfully.'))

  await selectBoth(user)
  await user.click(screen.getByRole('button', { name: 'Remove labels' }))
  expect(screen.queryByRole('button', { name: 'billing' })).not.toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Remove selected labels' })).toBeDisabled()
  await user.click(screen.getByRole('button', { name: 'vip' }))
  await user.click(screen.getByRole('button', { name: 'Remove selected labels' }))
  await waitFor(() =>
    expect(bulkBodies[1]).toEqual({
      type: 'Conversation',
      ids: [1, 2],
      labels: { remove: ['vip'] },
    }),
  )
  await waitFor(() => expect(alerts).toContain('Labels removed successfully.'))
})

test('agente: busca os atribuíveis das inboxes da seleção e pede confirmação', async () => {
  const inboxIds: string[] = []
  server.use(
    http.get('/api/v1/accounts/1/assignable_agents', ({ request }) => {
      inboxIds.push(...new URL(request.url).searchParams.getAll('inbox_ids[]'))
      return HttpResponse.json({
        payload: [
          {
            id: 9,
            name: 'Carla',
            available_name: 'Carla',
            thumbnail: '',
            availability_status: 'online',
          },
        ],
      })
    }),
  )
  const { user } = await setup()
  await selectBoth(user)
  await user.click(screen.getByRole('button', { name: 'Assign agent' }))
  await user.click(await screen.findByRole('button', { name: 'Carla' }))
  expect(inboxIds).toEqual(['1', '2'])
  expect(
    screen.getByText(
      (_, el) => el?.textContent === 'Are you sure you want to assign 2 conversations to Carla?',
    ),
  ).toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Yes' }))
  await waitFor(() =>
    expect(bulkBodies).toEqual([{ type: 'Conversation', ids: [1, 2], fields: { assignee_id: 9 } }]),
  )
  await waitFor(() => expect(alerts).toContain('Conversations assigned successfully.'))
})

test('time: None desatribui depois de confirmar; Cancel volta à lista', async () => {
  server.use(
    http.get('/api/v1/accounts/1/teams', () =>
      HttpResponse.json([{ id: 5, name: 'Suporte', account_id: 1 }]),
    ),
  )
  const { user } = await setup()
  await selectBoth(user)
  await user.click(screen.getByRole('button', { name: 'Assign team' }))
  await user.click(await screen.findByRole('button', { name: 'Suporte' }))
  await user.click(screen.getByRole('button', { name: 'Cancel' }))
  expect(screen.queryByRole('button', { name: 'Yes' })).not.toBeInTheDocument()

  await user.click(screen.getByRole('button', { name: 'None' }))
  expect(
    screen.getByText(
      (_, el) => el?.textContent === 'Are you sure you want to unassign 2 conversations?',
    ),
  ).toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Yes' }))
  await waitFor(() =>
    expect(bulkBodies).toEqual([{ type: 'Conversation', ids: [1, 2], fields: { team_id: 0 } }]),
  )
  await waitFor(() => expect(alerts).toContain('Teams assigned successfully.'))
})
