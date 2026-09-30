import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { beforeEach, describe, expect, test } from 'vitest'

import { contactFixture, conversationFixture } from '../../../test/conversation-fixtures'
import { profileFixture } from '../../../test/fixtures'
import { renderRoute } from '../../../test/render'
import { server } from '../../../test/server'
import { asSignedIn } from '../../../test/session'

let requests: URLSearchParams[]

beforeEach(() => {
  requests = []
  asSignedIn()
  server.use(
    http.get('/api/v1/accounts/1/conversations', ({ request }) => {
      requests.push(new URL(request.url).searchParams)
      const conversation = conversationFixture({
        id: 12,
        meta: { ...conversationFixture().meta, sender: contactFixture({ name: 'Ana Souza' }) },
      })
      return HttpResponse.json({
        data: {
          meta: { mine_count: 1, assigned_count: 1, unassigned_count: 0, all_count: 1 },
          payload: [conversation],
        },
      })
    }),
  )
})

test('os filtros da URL viram pedidos à API e aparecem na tela', async () => {
  await renderRoute('/app?status=resolved&team_id=2&conversation_type=mention&sort_by=unread')
  await screen.findByRole('link', { name: /Ana Souza/ })
  expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Mentions')
  const params = requests.at(-1)!
  expect(params.get('status')).toBe('resolved')
  expect(params.get('team_id')).toBe('2')
  expect(params.get('conversation_type')).toBe('mention')
  expect(params.get('sort_by')).toBe('unread')
})

test('parâmetros inválidos caem nos padrões', async () => {
  await renderRoute('/app?status=lixo&team_id=abc')
  await screen.findByRole('link', { name: /Ana Souza/ })
  const params = requests[0]
  expect(params.get('status')).toBe('open')
  expect(params.get('assignee_type')).toBe('me')
  expect(params.has('team_id')).toBe(false)
})

test('trocar de aba muda a URL e refaz a busca', async () => {
  const { router } = await renderRoute('/app')
  await userEvent.click(await screen.findByRole('tab', { name: /Unassigned/ }))
  await waitFor(() =>
    expect(router.state.location.search).toMatchObject({ assignee_type: 'unassigned' }),
  )
  await waitFor(() => expect(requests.map((p) => p.get('assignee_type'))).toContain('unassigned'))
})

test('abrir uma conversa navega para ela e mantém os filtros', async () => {
  const { router } = await renderRoute('/app?team_id=2&status=pending')
  await userEvent.click(await screen.findByRole('link', { name: /Ana Souza/ }))
  await waitFor(() => expect(router.state.location.pathname).toBe('/app/conversations/12'))
  expect(router.state.location.search).toMatchObject({ team_id: 2, status: 'pending' })
  // a lista continua na tela e destaca a conversa aberta
  expect(await screen.findByRole('link', { name: /Ana Souza/ })).toHaveAttribute(
    'aria-current',
    'page',
  )
})

describe('layout expandido', () => {
  const expanded = () =>
    asSignedIn(profileFixture({ ui_settings: { conversation_display_type: 'expanded' } }))

  test('o botão troca o layout e grava a preferência em ui_settings', async () => {
    const saved: unknown[] = []
    server.use(
      http.put('/api/v1/profile', async ({ request }) => {
        const body = (await request.json()) as { profile: { ui_settings: Record<string, unknown> } }
        saved.push(body.profile.ui_settings)
        return HttpResponse.json(profileFixture({ ui_settings: body.profile.ui_settings }))
      }),
    )
    await renderRoute('/app')
    await screen.findByRole('link', { name: /Ana Souza/ })
    // condensado: o vazio da conversa aparece ao lado da lista
    expect(screen.getByText(/Please select a conversation/)).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Switch the layout' }))
    await waitFor(() =>
      expect(saved.at(-1)).toMatchObject({
        conversation_display_type: 'expanded',
        previously_used_conversation_display_type: 'expanded',
      }),
    )
    // expandido sem conversa aberta: só a lista, em linhas
    await waitFor(() =>
      expect(screen.queryByText(/Please select a conversation/)).not.toBeInTheDocument(),
    )
    expect(screen.getByRole('link', { name: /Ana Souza/ })).toHaveTextContent('12')

    await userEvent.click(screen.getByRole('button', { name: 'Switch the layout' }))
    await waitFor(() =>
      expect(saved.at(-1)).toMatchObject({ conversation_display_type: 'condensed' }),
    )
  })

  test('com a conversa aberta a lista some e o voltar leva de volta a ela', async () => {
    expanded()
    server.use(
      http.get('/api/v1/accounts/1/conversations/12', () =>
        HttpResponse.json(
          conversationFixture({
            id: 12,
            meta: { ...conversationFixture().meta, sender: contactFixture({ name: 'Ana Souza' }) },
          }),
        ),
      ),
      http.get('/api/v1/accounts/1/conversations/12/messages', () =>
        HttpResponse.json({
          meta: {
            labels: [],
            additional_attributes: {},
            contact: { ...contactFixture(), type: 'contact' },
            agent_last_seen_at: null,
            assignee_last_seen_at: null,
          },
          payload: [],
        }),
      ),
      http.post(
        '/api/v1/accounts/1/conversations/12/update_last_seen',
        () => new HttpResponse(null, { status: 200 }),
      ),
    )
    const { router } = await renderRoute('/app/conversations/12?status=pending')
    await screen.findByRole('button', { name: '#12' })
    expect(screen.queryByRole('tab', { name: /Mine/ })).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: /Back/ }))
    await waitFor(() => expect(router.state.location.pathname).toBe('/app'))
    expect(router.state.location.search).toMatchObject({ status: 'pending' })
    expect(await screen.findByRole('tab', { name: /Mine/ })).toBeInTheDocument()
  })
})
