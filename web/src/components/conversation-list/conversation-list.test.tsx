import { act, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import type { Conversation } from '../../api/types'
import { contactFixture, conversationFixture } from '../../test/conversation-fixtures'
import { server } from '../../test/server'
import { ConversationList } from './conversation-list'
import { parseSearch, type ConversationsSearch } from './search'
import { renderWithApp } from './test-utils'

const counts = { mine_count: 4, assigned_count: 6, unassigned_count: 2, all_count: 8 }

function conversation(id: number, name = `Cliente ${id}`): Conversation {
  return conversationFixture({
    id,
    meta: { ...conversationFixture().meta, sender: contactFixture({ id, name }) },
  })
}

function respondWith(pages: Conversation[][], seen: URLSearchParams[] = []) {
  server.use(
    http.get('/api/v1/accounts/1/conversations', ({ request }) => {
      const params = new URL(request.url).searchParams
      seen.push(params)
      const page = Number(params.get('page') ?? 1)
      return HttpResponse.json({ data: { meta: counts, payload: pages[page - 1] ?? [] } })
    }),
  )
  return seen
}

const search = (overrides: Partial<ConversationsSearch> = {}) => ({
  ...parseSearch({}),
  ...overrides,
})

function list(props: Partial<React.ComponentProps<typeof ConversationList>> = {}) {
  return renderWithApp(<ConversationList search={search()} onSearchChange={() => {}} {...props} />)
}

// jsdom não tem IntersectionObserver: guardamos o callback para "rolar" a lista nos testes.
let scrollToEnd: () => void = () => {}
beforeEach(() => {
  vi.stubGlobal(
    'IntersectionObserver',
    class {
      constructor(callback: IntersectionObserverCallback) {
        scrollToEnd = () =>
          callback([{ isIntersecting: true } as IntersectionObserverEntry], this as never)
      }
      observe() {}
      disconnect() {}
      unobserve() {}
    },
  )
})
afterEach(() => vi.unstubAllGlobals())

test('mostra os cards e os contadores das abas', async () => {
  respondWith([[conversation(1, 'Ana Souza'), conversation(2, 'Bruno Lima')]])
  await list()
  expect(await screen.findByRole('link', { name: /Ana Souza/ })).toBeInTheDocument()
  expect(screen.getByRole('link', { name: /Bruno Lima/ })).toBeInTheDocument()
  expect(screen.getByRole('tab', { name: 'Mine 4' })).toBeInTheDocument()
  expect(screen.getByRole('tab', { name: 'Unassigned 2' })).toBeInTheDocument()
  expect(screen.getByRole('tab', { name: 'All 8' })).toBeInTheDocument()
})

test('enquanto carrega mostra "Fetching conversations"', async () => {
  server.use(http.get('/api/v1/accounts/1/conversations', () => new Promise(() => {})))
  await list()
  expect(await screen.findByText('Fetching conversations')).toBeInTheDocument()
})

test('pede à API os filtros da URL, na página 1', async () => {
  const seen = respondWith([[conversation(1)]])
  await list({
    search: search({
      status: 'pending',
      assignee_type: 'all',
      sort_by: 'unread',
      label: 'vip',
      team_id: 2,
      inbox_id: 5,
    }),
  })
  await screen.findByRole('link', { name: /Cliente 1/ })
  const params = seen[0]
  expect(params.get('status')).toBe('pending')
  expect(params.get('assignee_type')).toBe('all')
  expect(params.get('sort_by')).toBe('unread')
  expect(params.getAll('labels[]')).toEqual(['vip'])
  expect(params.get('team_id')).toBe('2')
  expect(params.get('inbox_id')).toBe('5')
  expect(params.get('page')).toBe('1')
})

test('trocar de aba avisa o pai (a URL é que muda o filtro)', async () => {
  respondWith([[conversation(1)]])
  const onSearchChange = vi.fn()
  await list({ onSearchChange })
  await userEvent.click(await screen.findByRole('tab', { name: /Unassigned/ }))
  expect(onSearchChange).toHaveBeenCalledWith({ assignee_type: 'unassigned' })
})

test('trocar status e ordenação avisam o pai', async () => {
  respondWith([[conversation(1)]])
  const onSearchChange = vi.fn()
  await list({ onSearchChange })
  await userEvent.click(await screen.findByRole('button', { name: 'Sort conversations' }))
  await userEvent.click(screen.getByRole('button', { name: 'Open' }))
  await userEvent.click(screen.getByRole('option', { name: 'Resolved' }))
  expect(onSearchChange).toHaveBeenCalledWith({ status: 'resolved' })
})

test('sem conversas mostra a mensagem de grupo vazio', async () => {
  respondWith([[]])
  await list()
  expect(
    await screen.findByText('There are no active conversations in this group.'),
  ).toBeInTheDocument()
  expect(screen.queryByText(/All conversations loaded/)).not.toBeInTheDocument()
})

test('erro da API mostra o aviso de falha', async () => {
  server.use(
    http.get('/api/v1/accounts/1/conversations', () =>
      HttpResponse.json({ error: 'x' }, { status: 500 }),
    ),
  )
  await list()
  expect(await screen.findByRole('alert')).toHaveTextContent(
    "Couldn't load conversations. Please try again.",
  )
})

test('página curta: tudo carregado, sem pedir mais', async () => {
  const seen = respondWith([[conversation(1)]])
  await list()
  expect(await screen.findByText('All conversations loaded 🎉')).toBeInTheDocument()
  act(() => scrollToEnd())
  expect(seen).toHaveLength(1)
})

test('rolar até o fim carrega a próxima página e depois mostra "All conversations loaded"', async () => {
  const first = Array.from({ length: 25 }, (_, i) => conversation(i + 1))
  const seen = respondWith([first, [conversation(26, 'Última Pessoa')]])
  await list()
  await screen.findByRole('link', { name: /Cliente 25/ })
  expect(screen.queryByText(/All conversations loaded/)).not.toBeInTheDocument()

  act(() => scrollToEnd())

  expect(await screen.findByRole('link', { name: /Última Pessoa/ })).toBeInTheDocument()
  expect(seen.map((p) => p.get('page'))).toEqual(['1', '2'])
  await screen.findByText('All conversations loaded 🎉')
  expect(screen.getAllByRole('link')).toHaveLength(26)
})

test('destaca a conversa aberta', async () => {
  respondWith([[conversation(1, 'Ana Souza'), conversation(2, 'Bruno Lima')]])
  await list({ activeId: 2 })
  await screen.findByRole('link', { name: /Ana Souza/ })
  expect(screen.getByRole('link', { name: /Bruno Lima/ })).toHaveAttribute('aria-current', 'page')
  expect(screen.getByRole('link', { name: /Ana Souza/ })).not.toHaveAttribute('aria-current')
})

test('os links levam para a conversa, usando o renderizador do roteador', async () => {
  respondWith([[conversation(7, 'Ana Souza')]])
  await list({
    renderCardLink: (conv, { children, ...rest }) => (
      <a href={`/app/conversations/${conv.id}?status=open`} {...rest}>
        {children}
      </a>
    ),
  })
  expect(await screen.findByRole('link', { name: /Ana Souza/ })).toHaveAttribute(
    'href',
    '/app/conversations/7?status=open',
  )
})

test.each([
  [{ conversation_type: 'mention' as const }, 'Mentions'],
  [{ conversation_type: 'unattended' as const }, 'Unattended'],
  [{ conversation_type: 'participating' as const }, 'Participating'],
  [{ label: 'vip' }, '#vip'],
  [{}, 'Conversations'],
])('título da lista para %j', async (overrides, title) => {
  respondWith([[conversation(1)]])
  await list({ search: search(overrides) })
  const header = await screen.findByRole('heading', { level: 1 })
  expect(within(header.parentElement as HTMLElement).getByText(title)).toBeInTheDocument()
})

test('trocar o filtro busca de novo do começo', async () => {
  const seen = respondWith([[conversation(1)]])
  const { rerender, queryClient } = await list()
  await screen.findByRole('link', { name: /Cliente 1/ })
  expect(queryClient.isFetching()).toBe(0)

  rerender(<ConversationList search={search({ status: 'resolved' })} onSearchChange={() => {}} />)
  await waitFor(() => expect(seen.map((p) => p.get('status'))).toEqual(['open', 'resolved']))
})
