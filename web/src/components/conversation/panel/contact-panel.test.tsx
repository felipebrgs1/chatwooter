import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { expect, test } from 'vitest'

import { profileQuery } from '../../../api/auth'
import { contactFixture, conversationFixture } from '../../../test/conversation-fixtures'
import { profileFixture } from '../../../test/fixtures'
import { server } from '../../../test/server'
import { ConversationView } from '../conversation-view'
import { renderConversation } from '../test-utils'

const BASE = '/api/v1/accounts/1/conversations/1'

type Calls = {
  settings: Record<string, unknown>[]
  assignments: unknown[]
  priority: unknown[]
  labels: unknown[]
}

function api(conversation: Partial<ReturnType<typeof conversationFixture>> = {}) {
  const calls: Calls = { settings: [], assignments: [], priority: [], labels: [] }
  let labels: string[] = []
  server.use(
    http.get(BASE, () => HttpResponse.json(conversationFixture({ id: 1, ...conversation }))),
    http.get(`${BASE}/messages`, () =>
      HttpResponse.json({
        meta: {
          labels: [],
          additional_attributes: {},
          contact: {},
          agent_last_seen_at: null,
          assignee_last_seen_at: null,
        },
        payload: [],
      }),
    ),
    http.post(`${BASE}/update_last_seen`, () => new HttpResponse(null, { status: 200 })),
    http.get('/api/v1/accounts/1/contacts/100', () =>
      HttpResponse.json({
        payload: {
          ...contactFixture(),
          additional_attributes: { company_name: 'Acme', city: 'Recife', country: 'Brazil' },
          created_at: 1_790_000_000,
        },
      }),
    ),
    http.put('/api/v1/profile', async ({ request }) => {
      const body = (await request.json()) as { profile: { ui_settings: Record<string, unknown> } }
      calls.settings.push(body.profile.ui_settings)
      return HttpResponse.json(profileFixture({ ui_settings: body.profile.ui_settings }))
    }),
    http.get('/api/v1/accounts/1/agents', () =>
      HttpResponse.json([
        {
          id: 10,
          name: 'Ana Souza',
          available_name: 'Ana Souza',
          email: 'ana@example.com',
          role: 'administrator',
          availability_status: 'online',
          account_id: 1,
          auto_offline: true,
          confirmed: true,
          provider: 'email',
          thumbnail: '',
        },
        {
          id: 11,
          name: 'Bruno Lima',
          available_name: 'Bruno Lima',
          email: 'bruno@example.com',
          role: 'agent',
          availability_status: 'busy',
          account_id: 1,
          auto_offline: true,
          confirmed: true,
          provider: 'email',
          thumbnail: '',
        },
      ]),
    ),
    http.get('/api/v1/accounts/1/teams', () =>
      HttpResponse.json([
        {
          id: 3,
          name: 'Vendas',
          description: null,
          allow_auto_assign: true,
          icon: '',
          icon_color: '',
          account_id: 1,
          is_member: true,
        },
      ]),
    ),
    http.get('/api/v1/accounts/1/labels', () =>
      HttpResponse.json({
        payload: [
          { id: 1, title: 'billing', description: null, color: '#ff0000', show_on_sidebar: true },
          { id: 2, title: 'vip', description: null, color: '#00ff00', show_on_sidebar: true },
        ],
      }),
    ),
    http.post(`${BASE}/assignments`, async ({ request }) => {
      calls.assignments.push(await request.json())
      return HttpResponse.json(null)
    }),
    http.post(`${BASE}/toggle_priority`, async ({ request }) => {
      calls.priority.push(await request.json())
      return new HttpResponse(null, { status: 200 })
    }),
    http.get(`${BASE}/labels`, () => HttpResponse.json({ payload: labels })),
    http.post(`${BASE}/labels`, async ({ request }) => {
      const body = (await request.json()) as { labels: string[] }
      calls.labels.push(body)
      labels = body.labels
      return HttpResponse.json({ payload: labels })
    }),
  )
  return calls
}

async function open(uiSettings: Record<string, unknown> = {}) {
  const view = await renderConversation(<ConversationView conversationId={1} />)
  view.queryClient.setQueryData(profileQuery.queryKey, profileFixture({ ui_settings: uiSettings }))
  return view
}

test('o botão de contato abre e fecha o painel, gravando em ui_settings (e Alt+O também)', async () => {
  const calls = api()
  const user = userEvent.setup()
  await open()

  await user.click(await screen.findByRole('button', { name: 'Contact' }))
  const panel = await screen.findByRole('complementary', { name: 'Contact' })
  expect(calls.settings.at(-1)).toMatchObject({
    is_contact_sidebar_open: true,
    is_copilot_panel_open: false,
  })

  await user.click(within(panel).getByRole('button', { name: 'Close' }))
  await waitFor(() =>
    expect(screen.queryByRole('complementary', { name: 'Contact' })).not.toBeInTheDocument(),
  )
  expect(calls.settings.at(-1)).toMatchObject({ is_contact_sidebar_open: false })

  await user.keyboard('{Alt>}o{/Alt}')
  expect(await screen.findByRole('complementary', { name: 'Contact' })).toBeInTheDocument()
})

test('o painel mostra os dados do contato', async () => {
  api()
  await open({ is_contact_sidebar_open: true })
  const panel = await screen.findByRole('complementary', { name: 'Contact' })
  expect(await within(panel).findByRole('heading', { name: 'Maria Cliente' })).toBeInTheDocument()
  expect(within(panel).getByRole('link', { name: /maria@example.com/ })).toHaveAttribute(
    'href',
    'mailto:maria@example.com',
  )
  expect(within(panel).getByRole('link', { name: /\+5511999990000/ })).toHaveAttribute(
    'href',
    'tel:+5511999990000',
  )
  expect(within(panel).getByText('Acme')).toBeInTheDocument()
  // sem country_code o Chatwoot põe o globo no lugar da bandeira
  expect(within(panel).getByText('Recife, Brazil 🌎')).toBeInTheDocument()
})

test('Conversation Actions abre e fecha, lembrando em ui_settings', async () => {
  const calls = api()
  const user = userEvent.setup()
  await open({ is_contact_sidebar_open: true })
  const panel = await screen.findByRole('complementary', { name: 'Contact' })

  await user.click(within(panel).getByRole('button', { name: 'Conversation Actions' }))
  expect(await within(panel).findByText('Assigned Agent')).toBeInTheDocument()
  expect(calls.settings.at(-1)).toMatchObject({ is_conv_actions_open: true })
})

test('atribuir a mim, escolher time e prioridade', async () => {
  const calls = api()
  const user = userEvent.setup()
  await open({ is_contact_sidebar_open: true, is_conv_actions_open: true })
  const panel = await screen.findByRole('complementary', { name: 'Contact' })

  await user.click(await within(panel).findByRole('button', { name: /Assign to me/ }))
  await waitFor(() => expect(calls.assignments).toContainEqual({ assignee_id: 10 }))
  expect(await screen.findByText('Conversation Assignee changed')).toBeInTheDocument()

  await user.click(within(panel).getByRole('button', { name: 'Select team' }))
  await user.click(await within(panel).findByRole('button', { name: 'Vendas' }))
  await waitFor(() => expect(calls.assignments).toContainEqual({ team_id: 3 }))

  await user.click(within(panel).getByRole('button', { name: 'Priority' }))
  await user.click(await within(panel).findByRole('button', { name: 'High' }))
  await waitFor(() => expect(calls.priority).toContainEqual({ priority: 'high' }))
  expect(
    await screen.findByText('Changed priority of conversation id 1 to High'),
  ).toBeInTheDocument()
})

test('etiquetas: adicionar pela lista e remover pelo chip', async () => {
  const calls = api()
  const user = userEvent.setup()
  await open({ is_contact_sidebar_open: true, is_conv_actions_open: true })
  const panel = await screen.findByRole('complementary', { name: 'Contact' })

  await user.click(await within(panel).findByRole('button', { name: 'Add Labels' }))
  await user.click(await within(panel).findByRole('button', { name: 'billing' }))
  await waitFor(() => expect(calls.labels).toContainEqual({ labels: ['billing'] }))

  // a lista continua aberta depois de escolher (como no LabelDropdown); o chip já aparece ao lado
  await user.click(await within(panel).findByRole('button', { name: 'Remove billing' }))
  await waitFor(() => expect(calls.labels.at(-1)).toEqual({ labels: [] }))
})
