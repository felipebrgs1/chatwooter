import { screen, waitFor } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { expect, test } from 'vitest'

import {
  contactFixture,
  conversationFixture,
  messageFixture,
} from '../../../../test/conversation-fixtures'
import { renderRoute } from '../../../../test/render'
import { server } from '../../../../test/server'
import { asSignedIn } from '../../../../test/session'

const BASE = '/api/v1/accounts/1/conversations'

function mockApi() {
  asSignedIn()
  server.use(
    // a lista (outro agente) só precisa de uma resposta válida vazia
    http.get(BASE, () =>
      HttpResponse.json({
        data: {
          meta: { mine_count: 0, assigned_count: 0, unassigned_count: 0, all_count: 0 },
          payload: [],
        },
      }),
    ),
    http.get(`${BASE}/:id`, ({ params }) =>
      HttpResponse.json(
        conversationFixture({
          id: Number(params.id),
          meta: {
            sender: contactFixture({ name: 'Cliente da URL' }),
            channel: 'Channel::Telegram',
            hmac_verified: null,
          },
        }),
      ),
    ),
    http.get(`${BASE}/:id/messages`, () =>
      HttpResponse.json({
        meta: {
          labels: [],
          additional_attributes: {},
          contact: { ...contactFixture(), type: 'contact' },
          agent_last_seen_at: null,
          assignee_last_seen_at: null,
        },
        payload: [messageFixture({ id: 1, content: 'primeira da URL' })],
      }),
    ),
    http.post(`${BASE}/:id/update_last_seen`, () => new HttpResponse(null, { status: 200 })),
  )
}

test('/app/conversations/7 abre a conversa de display_id 7', async () => {
  mockApi()
  const { router } = await renderRoute('/app/conversations/7')
  expect(await screen.findByText('Cliente da URL')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: '#7' })).toBeInTheDocument()
  expect(await screen.findByText('primeira da URL')).toBeInTheDocument()
  expect(router.state.location.pathname).toBe('/app/conversations/7')
})

test('/app mostra o pedido para escolher uma conversa', async () => {
  mockApi()
  const { router } = await renderRoute('/app')
  await waitFor(() => expect(router.state.location.pathname).toBe('/app'))
  expect(await screen.findByText('Please select a conversation from left pane')).toBeInTheDocument()
})
