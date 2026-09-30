import { fireEvent, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { messageFixture } from '../../test/conversation-fixtures'
import { renderWithI18n } from '../../test/i18n'
import { Message } from './message'
import type { ThreadMessage } from './message-variant'

const agent = { id: 7, name: 'Ana Souza', type: 'user' as const }
const build = (o: Partial<ThreadMessage> = {}): ThreadMessage =>
  ({ ...messageFixture(), ...o }) as ThreadMessage

async function show(m: ThreadMessage, props: Partial<Parameters<typeof Message>[0]> = {}) {
  return renderWithI18n(<Message message={m} channel="Channel::Telegram" {...props} />)
}

test('mensagem do cliente: à esquerda, sem status de entrega', async () => {
  await show(build({ content: 'Olá' }))
  const row = screen.getByText('Olá').closest('[data-message-id]')
  expect(row).toHaveClass('justify-start')
  expect(screen.queryByLabelText('Sent successfully')).toBeNull()
})

test('mensagem do agente: à direita, com avatar e status enviado (Telegram exige source_id)', async () => {
  await show(
    build({ message_type: 1, content: 'Oi', sender: agent, source_id: '99', status: 'sent' }),
  )
  expect(screen.getByText('Oi').closest('[data-message-id]')).toHaveClass('justify-end')
  expect(screen.getByLabelText('Sent successfully')).toBeInTheDocument()
})

test('saída ainda sem source_id aparece como enviando', async () => {
  await show(
    build({ message_type: 1, content: 'Oi', sender: agent, source_id: null, status: 'sent' }),
  )
  expect(screen.getByLabelText('Sending')).toBeInTheDocument()
})

test('WhatsApp mostra entregue e lido', async () => {
  const base = { message_type: 1 as const, content: 'x', sender: agent, source_id: 'w1' }
  const { unmount } = await show(build({ ...base, status: 'delivered' }), {
    channel: 'Channel::Whatsapp',
  })
  expect(screen.getByLabelText('Delivered successfully')).toBeInTheDocument()
  unmount()
  await show(build({ ...base, status: 'read' }), { channel: 'Channel::Whatsapp' })
  expect(screen.getByLabelText('Read successfully')).toBeInTheDocument()
})

test('nota privada: marcada como privada, com cadeado e sem status', async () => {
  await show(build({ private: true, message_type: 1, content: 'só equipe', sender: agent }))
  expect(screen.getByText('só equipe').closest('[data-variant]')).toHaveAttribute(
    'data-variant',
    'private',
  )
  expect(screen.queryByLabelText('Sent successfully')).toBeNull()
  expect(screen.getByTestId('private-lock')).toBeInTheDocument()
})

test('atividade fica centralizada e sem meta', async () => {
  await show(build({ message_type: 2, content: 'Conversa resolvida', sender: undefined }))
  const text = screen.getByText('Conversa resolvida')
  expect(text.closest('[data-message-id]')).toHaveClass('justify-center')
  expect(document.querySelector('time')).toBeNull()
})

test('falha de envio mostra o aviso e permite tentar de novo', async () => {
  const onRetry = vi.fn()
  await show(
    build({
      message_type: 1,
      sender: agent,
      status: 'failed',
      created_at: Math.floor(Date.now() / 1000),
      content: 'nao foi',
      content_attributes: { external_error: 'Bot was blocked by the user' },
    }),
    { onRetry },
  )
  expect(screen.getByText('Failed to send')).toBeInTheDocument()
  expect(screen.getByText('Bot was blocked by the user')).toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Retry' }))
  expect(onRetry).toHaveBeenCalledTimes(1)
})

test('agrupada com a próxima: sem horário nem avatar', async () => {
  await show(build({ message_type: 1, content: 'a', sender: agent, source_id: '1' }), {
    groupWithNext: true,
  })
  expect(document.querySelector('time')).toBeNull()
})

test('horário exibido quando não agrupa', async () => {
  await show(build({ content: 'a' }))
  expect(document.querySelector('time')).not.toBeNull()
})

const attachment = (file_type: 'image' | 'video' | 'audio' | 'file', data_url: string) => ({
  id: 1,
  message_id: 1,
  file_type,
  account_id: 1,
  extension: null,
  data_url,
  thumb_url: '',
  file_size: 10,
})

test('imagem: mostra a figura e, se quebrar, avisa', async () => {
  await show(build({ content: null, attachments: [attachment('image', 'https://cdn.test/a.png')] }))
  const img = document.querySelector('img') as HTMLImageElement
  expect(img).toHaveAttribute('src', 'https://cdn.test/a.png')
  fireEvent.error(img)
  expect(screen.getByText('This image is no longer available.')).toBeInTheDocument()
})

test('vídeo e áudio usam os players nativos', async () => {
  const { unmount } = await show(
    build({ content: null, attachments: [attachment('video', 'https://cdn.test/v.mp4')] }),
  )
  expect(document.querySelector('video')).toHaveAttribute('src', 'https://cdn.test/v.mp4')
  unmount()
  await show(build({ content: null, attachments: [attachment('audio', 'https://cdn.test/a.ogg')] }))
  expect(document.querySelector('audio')).toHaveAttribute('src', 'https://cdn.test/a.ogg')
})

test('arquivo: nome do arquivo e link de download', async () => {
  await show(
    build({
      content: null,
      attachments: [attachment('file', 'https://cdn.test/docs/contrato%20final.pdf')],
    }),
  )
  expect(screen.getByText('contrato final.pdf')).toBeInTheDocument()
  expect(screen.getByRole('link', { name: 'Download' })).toHaveAttribute(
    'href',
    'https://cdn.test/docs/contrato%20final.pdf',
  )
})

test('texto com anexo mostra os dois', async () => {
  await show(
    build({ content: 'veja', attachments: [attachment('file', 'https://cdn.test/x.pdf')] }),
  )
  expect(screen.getByText('veja')).toBeInTheDocument()
  expect(screen.getByText('x.pdf')).toBeInTheDocument()
})
