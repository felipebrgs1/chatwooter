import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { beforeEach, expect, test } from 'vitest'

import { contactFixture, conversationFixture } from '../../../test/conversation-fixtures'
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
  const params = requests.at(-1)!
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
  await waitFor(() => expect(requests.at(-1)!.get('assignee_type')).toBe('unassigned'))
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
