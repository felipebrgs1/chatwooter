import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'

import {
  contactFixture,
  conversationFixture,
  messageFixture,
} from '../../test/conversation-fixtures'
import { renderWithI18n } from '../../test/i18n'
import { ConversationCard } from './conversation-card'

const now = new Date(1_790_000_000_000 + 5 * 3600 * 1000)

function renderCard(overrides: Parameters<typeof conversationFixture>[0] = {}, props = {}) {
  return renderWithI18n(
    <ConversationCard
      conversation={conversationFixture(overrides)}
      href="/app/conversations/1"
      now={now}
      {...props}
    />,
  )
}

test('é um link para a conversa com o nome do contato e a prévia', async () => {
  await renderCard()
  const link = screen.getByRole('link', { name: /Maria Cliente/ })
  expect(link).toHaveAttribute('href', '/app/conversations/1')
  expect(screen.getByText('Olá, preciso de ajuda')).toBeInTheDocument()
})

test('mostra quanto tempo faz desde a criação e a última atividade', async () => {
  await renderCard()
  expect(screen.getByText('5h • 5h')).toBeInTheDocument()
})

test('badge de não lidas: número, e 9+ acima de nove', async () => {
  await renderCard({ unread_count: 3 })
  expect(screen.getByTestId('unread')).toHaveTextContent('3')
})

test('mais de nove não lidas viram 9+', async () => {
  await renderCard({ unread_count: 42 })
  expect(screen.getByTestId('unread')).toHaveTextContent('9+')
})

test('sem não lidas não há badge', async () => {
  await renderCard({ unread_count: 0 })
  expect(screen.queryByTestId('unread')).not.toBeInTheDocument()
})

test('usa a última mensagem que não é atividade', async () => {
  await renderCard({
    messages: [messageFixture({ id: 2, message_type: 2, content: 'Conversa atribuída' })],
    last_non_activity_message: messageFixture({ id: 1, content: 'Mensagem real' }),
  })
  expect(screen.getByText('Mensagem real')).toBeInTheDocument()
  expect(screen.queryByText('Conversa atribuída')).not.toBeInTheDocument()
})

test('sem nenhuma mensagem mostra "No Messages"', async () => {
  await renderCard({ messages: [], last_non_activity_message: null })
  expect(screen.getByText('No Messages')).toBeInTheDocument()
})

test('destaca a conversa aberta', async () => {
  await renderCard({}, { active: true })
  expect(screen.getByRole('link', { name: /Maria Cliente/ })).toHaveAttribute(
    'aria-current',
    'page',
  )
})

test('mostra a prioridade quando existe', async () => {
  await renderCard({ priority: 'urgent' })
  expect(screen.getByTitle('Urgent')).toBeInTheDocument()
})

test('mostra o agente responsável só quando pedido', async () => {
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
  const overrides = {
    meta: { sender: contactFixture(), channel: 'Channel::Telegram', hmac_verified: null, assignee },
  }
  await renderCard(overrides)
  expect(screen.queryByText('Ana Agente')).not.toBeInTheDocument()
})

test('com showAssignee mostra o nome do agente', async () => {
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
  await renderCard(
    {
      meta: {
        sender: contactFixture(),
        channel: 'Channel::Telegram',
        hmac_verified: null,
        assignee,
      },
    },
    { showAssignee: true },
  )
  expect(screen.getByText('Ana Agente')).toBeInTheDocument()
})

test('lista as etiquetas da conversa', async () => {
  await renderCard({ labels: ['vip', 'cobrança'] })
  expect(screen.getByText('vip')).toBeInTheDocument()
  expect(screen.getByText('cobrança')).toBeInTheDocument()
})

test('usa o renderizador de link recebido (o roteador)', async () => {
  await renderCard(
    {},
    {
      renderLink: ({ children, className }: { children: React.ReactNode; className: string }) => (
        <a data-router href="/x" className={className}>
          {children}
        </a>
      ),
    },
  )
  expect(screen.getByRole('link', { name: /Maria Cliente/ })).toHaveAttribute('data-router')
})
