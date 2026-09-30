import { screen, within } from '@testing-library/react'
import { expect, test } from 'vitest'

import type { Conversation } from '../../api/types'
import { conversationFixture, messageFixture } from '../../test/conversation-fixtures'
import { renderWithI18n } from '../../test/i18n'
import { ConversationCardExpanded } from './conversation-card-expanded'

const now = new Date(1_790_000_000_000 + 5 * 3600 * 1000)

const assignee = {
  id: 9,
  account_id: 1,
  availability_status: 'online' as const,
  auto_offline: true,
  confirmed: true,
  email: 'a@b.c',
  provider: 'email',
  available_name: 'Ana Agente',
  name: 'Ana',
  role: 'agent' as const,
  thumbnail: '',
}

function renderRow(overrides: Partial<Conversation> = {}, props = {}) {
  return renderWithI18n(
    <ConversationCardExpanded
      conversation={conversationFixture(overrides)}
      href="/app/conversations/1"
      now={now}
      {...props}
    />,
  )
}

test('é uma linha-link com #id, contato, prévia e tempos', async () => {
  await renderRow({ id: 42 })
  const row = screen.getByRole('link', { name: /Maria Cliente/ })
  expect(row).toHaveAttribute('href', '/app/conversations/1')
  expect(within(row).getByTitle('42')).toHaveTextContent('42')
  expect(within(row).getByRole('heading', { name: 'Maria Cliente' })).toBeInTheDocument()
  expect(within(row).getByText('Olá, preciso de ajuda')).toBeInTheDocument()
  expect(within(row).getByText('5h • 5h')).toBeInTheDocument()
})

test('status e prioridade aparecem mesmo vazios (show-empty)', async () => {
  await renderRow({ status: 'open', priority: null })
  expect(screen.getByTitle('open')).toBeInTheDocument()
  expect(screen.getByTitle('None')).toBeInTheDocument()
})

test('prioridade definida usa o nome traduzido', async () => {
  await renderRow({ priority: 'high' })
  expect(screen.getByTitle('High')).toBeInTheDocument()
})

test('sempre mostra o agente responsável', async () => {
  await renderRow({ meta: { ...conversationFixture().meta, assignee } })
  expect(screen.getByTitle('Ana Agente')).toBeInTheDocument()
})

test('badge de não lidas', async () => {
  await renderRow({ unread_count: 12 })
  expect(screen.getByTestId('unread')).toHaveTextContent('9+')
})

test('etiquetas à direita', async () => {
  await renderRow({ labels: ['vip'] })
  expect(screen.getByText('vip')).toBeInTheDocument()
})

test('nome da inbox só quando pedido', async () => {
  await renderRow({}, { inboxName: 'Suporte' })
  expect(screen.getByText('Suporte')).toBeInTheDocument()
})

test('usa a última mensagem que não é atividade', async () => {
  await renderRow({
    messages: [messageFixture({ id: 2, message_type: 2, content: 'Conversa atribuída' })],
    last_non_activity_message: messageFixture({ id: 1, content: 'Mensagem real' }),
  })
  expect(screen.getByText('Mensagem real')).toBeInTheDocument()
})

test('destaca a conversa aberta', async () => {
  await renderRow({}, { active: true })
  expect(screen.getByRole('link', { name: /Maria Cliente/ })).toHaveAttribute(
    'aria-current',
    'page',
  )
})
