import { act, fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { expect, test, vi } from 'vitest'

import type { Message } from '../../api/types'
import {
  contactFixture,
  conversationFixture,
  messageFixture,
} from '../../test/conversation-fixtures'
import { server } from '../../test/server'
import { ConversationView } from './conversation-view'
import { renderConversation } from './test-utils'

const BASE = '/api/v1/accounts/1/conversations/1'
const NOW = Math.floor(Date.now() / 1000)

function messages(ids: number[], overrides: (id: number) => Partial<Message> = () => ({})) {
  return ids.map((id) =>
    messageFixture({
      id,
      content: `mensagem ${id}`,
      created_at: NOW - (100 - id) * 120,
      ...overrides(id),
    }),
  )
}

function page(payload: Message[]) {
  return {
    meta: {
      labels: [],
      additional_attributes: {},
      contact: { ...contactFixture(), type: 'contact' },
      agent_last_seen_at: null,
      assignee_last_seen_at: null,
    },
    payload,
  }
}

function api(
  options: {
    conversation?: Partial<ReturnType<typeof conversationFixture>>
    payload?: Message[]
  } = {},
) {
  const calls = {
    seen: 0,
    toggle: [] as unknown[],
    sent: [] as unknown[],
    before: [] as (string | null)[],
  }
  server.use(
    http.get(BASE, () =>
      HttpResponse.json(conversationFixture({ id: 1, ...options.conversation })),
    ),
    http.get(`${BASE}/messages`, ({ request }) => {
      calls.before.push(new URL(request.url).searchParams.get('before'))
      return HttpResponse.json(page(options.payload ?? messages([1, 2, 3])))
    }),
    http.post(`${BASE}/update_last_seen`, () => {
      calls.seen += 1
      return new HttpResponse(null, { status: 200 })
    }),
  )
  return calls
}

test('cabeçalho: contato, #id e canal; a thread lista as mensagens em ordem', async () => {
  api({
    conversation: {
      meta: {
        sender: contactFixture({ name: 'Maria Cliente' }),
        channel: 'Channel::Telegram',
        hmac_verified: null,
      },
    },
  })
  await renderConversation(<ConversationView conversationId={1} />)

  expect(await screen.findByText('Maria Cliente')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: '#1' })).toBeInTheDocument()
  const texts = (await screen.findAllByText(/^mensagem \d$/)).map((n) => n.textContent)
  expect(texts).toEqual(['mensagem 1', 'mensagem 2', 'mensagem 3'])
})

test('abrir a conversa marca como vista uma única vez', async () => {
  const calls = api()
  await renderConversation(<ConversationView conversationId={1} />)
  await screen.findByText('mensagem 3')
  await waitFor(() => expect(calls.seen).toBe(1))
})

test('copiar o #id avisa por toast', async () => {
  api()
  const writeText = vi.fn().mockResolvedValue(undefined)
  Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText } })
  await renderConversation(<ConversationView conversationId={1} />)
  await userEvent.click(await screen.findByRole('button', { name: '#1' }))
  expect(writeText).toHaveBeenCalledWith('1')
  expect(await screen.findByText('Conversation ID copied to clipboard')).toBeInTheDocument()
})

test('Resolve chama toggle_status e vira Reopen', async () => {
  api()
  const toggle = vi.fn()
  server.use(
    http.post(`${BASE}/toggle_status`, async ({ request }) => {
      toggle(await request.json())
      return HttpResponse.json({
        meta: {},
        payload: {
          success: true,
          conversation_id: 1,
          current_status: 'resolved',
          snoozed_until: null,
        },
      })
    }),
  )
  await renderConversation(<ConversationView conversationId={1} />)
  await userEvent.click(await screen.findByRole('button', { name: 'Resolve' }))
  expect(toggle).toHaveBeenCalledWith({ status: 'resolved' })
  expect(await screen.findByRole('button', { name: 'Reopen' })).toBeInTheDocument()
})

test('conversa pendente mostra Open', async () => {
  api({ conversation: { status: 'pending' } })
  await renderConversation(<ConversationView conversationId={1} />)
  expect(await screen.findByRole('button', { name: 'Open' })).toBeInTheDocument()
})

test('envio otimista: aparece na hora como "Sending" e é reconciliado sem duplicar', async () => {
  api()
  let release!: () => void
  const gate = new Promise<void>((r) => (release = r))
  const sent: { content: string; private: boolean; echo_id: string }[] = []
  server.use(
    http.post(`${BASE}/messages`, async ({ request }) => {
      const body = (await request.json()) as (typeof sent)[number]
      sent.push(body)
      await gate
      return HttpResponse.json(
        messageFixture({
          id: 50,
          content: body.content,
          message_type: 1,
          echo_id: body.echo_id,
          source_id: 'tg-1',
          status: 'sent',
          created_at: NOW,
          sender: { id: 10, name: 'Ana Souza', type: 'user' },
        }),
      )
    }),
  )
  await renderConversation(<ConversationView conversationId={1} />)
  await screen.findByText('mensagem 3')

  await userEvent.type(screen.getByPlaceholderText(/Shift \+ enter/), 'resposta nova{Enter}')

  expect(screen.getByText('resposta nova')).toBeInTheDocument()
  expect(screen.getByLabelText('Sending')).toBeInTheDocument()
  await waitFor(() => expect(sent).toHaveLength(1))
  expect(sent[0]).toMatchObject({ content: 'resposta nova', private: false })
  expect(sent[0].echo_id).toBeTruthy()

  await act(async () => release())
  await waitFor(() => expect(screen.getByLabelText('Sent successfully')).toBeInTheDocument())
  expect(screen.getAllByText('resposta nova')).toHaveLength(1)
  expect(screen.queryByLabelText('Sending')).toBeNull()
})

test('nota privada é enviada com private=true', async () => {
  api()
  const sent = vi.fn()
  server.use(
    http.post(`${BASE}/messages`, async ({ request }) => {
      const body = (await request.json()) as { content: string; echo_id: string }
      sent(body)
      return HttpResponse.json(
        messageFixture({
          id: 51,
          content: body.content,
          private: true,
          message_type: 1,
          echo_id: body.echo_id,
          sender: { id: 10, name: 'Ana Souza', type: 'user' },
        }),
      )
    }),
  )
  await renderConversation(<ConversationView conversationId={1} />)
  await screen.findByText('mensagem 3')
  await userEvent.click(screen.getByRole('button', { name: 'Private Note' }))
  await userEvent.type(screen.getByPlaceholderText(/visible only to Agents/), 'só equipe{Enter}')
  await waitFor(() =>
    expect(sent).toHaveBeenCalledWith(
      expect.objectContaining({ content: 'só equipe', private: true }),
    ),
  )
})

test('falha no envio mostra erro e o reenvio usa o mesmo echo_id', async () => {
  api()
  const echoes: string[] = []
  let attempt = 0
  server.use(
    http.post(`${BASE}/messages`, async ({ request }) => {
      const body = (await request.json()) as { content: string; echo_id: string }
      echoes.push(body.echo_id)
      attempt += 1
      if (attempt === 1) return HttpResponse.json({ error: 'boom' }, { status: 500 })
      return HttpResponse.json(
        messageFixture({
          id: 60,
          content: body.content,
          message_type: 1,
          echo_id: body.echo_id,
          source_id: 'tg-2',
          sender: { id: 10, name: 'Ana Souza', type: 'user' },
        }),
      )
    }),
  )
  await renderConversation(<ConversationView conversationId={1} />)
  await screen.findByText('mensagem 3')
  await userEvent.type(screen.getByPlaceholderText(/Shift \+ enter/), 'vai falhar{Enter}')

  expect(await screen.findByText('Failed to send')).toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Retry' }))

  await waitFor(() => expect(screen.queryByText('Failed to send')).toBeNull())
  expect(echoes).toHaveLength(2)
  expect(echoes[1]).toBe(echoes[0])
  expect(screen.getAllByText('vai falhar')).toHaveLength(1)
})

test('rolar até o topo carrega as mensagens anteriores (before = id da mais antiga)', async () => {
  const newest = messages(Array.from({ length: 20 }, (_, i) => 21 + i)) // 21..40
  const older = messages(Array.from({ length: 5 }, (_, i) => 16 + i)) // 16..20
  const calls = { before: [] as (string | null)[] }
  server.use(
    http.get(BASE, () => HttpResponse.json(conversationFixture({ id: 1 }))),
    http.post(`${BASE}/update_last_seen`, () => new HttpResponse(null, { status: 200 })),
    http.get(`${BASE}/messages`, ({ request }) => {
      const before = new URL(request.url).searchParams.get('before')
      calls.before.push(before)
      return HttpResponse.json(page(before ? older : newest))
    }),
  )
  await renderConversation(<ConversationView conversationId={1} />)
  await screen.findByText('mensagem 40')

  const list = screen.getByTestId('message-list')
  list.scrollTop = 0
  fireEvent.scroll(list)

  expect(await screen.findByText('mensagem 16')).toBeInTheDocument()
  expect(calls.before).toEqual([null, '21'])
  // fim do histórico: rolar de novo não pede mais nada
  fireEvent.scroll(list)
  await waitFor(() => expect(calls.before).toHaveLength(2))
  const all = within(list)
    .getAllByText(/^mensagem \d+$/)
    .map((n) => n.textContent)
  expect(all[0]).toBe('mensagem 16')
  expect(all.at(-1)).toBe('mensagem 40')
})

test('conversa inexistente mostra o aviso', async () => {
  server.use(
    http.get(BASE, () =>
      HttpResponse.json({ error: 'Resource could not be found' }, { status: 404 }),
    ),
  )
  await renderConversation(<ConversationView conversationId={1} />)
  expect(
    await screen.findByText('Sorry, we cannot find the conversation. Please try again'),
  ).toBeInTheDocument()
})

test('can_reply=false trava a resposta pública', async () => {
  api({ conversation: { can_reply: false } })
  await renderConversation(<ConversationView conversationId={1} />)
  expect(await screen.findByText('You cannot reply to this conversation')).toBeInTheDocument()
})
