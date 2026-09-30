import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'

import { messageFixture } from '../../test/conversation-fixtures'
import { renderWithI18n } from '../../test/i18n'
import { MessagePreview } from './message-preview'

test('sem mensagem mostra "No Messages"', async () => {
  await renderWithI18n(<MessagePreview message={null} />)
  expect(screen.getByText('No Messages')).toBeInTheDocument()
})

test('mostra o texto da mensagem', async () => {
  await renderWithI18n(<MessagePreview message={messageFixture({ content: 'Quero cancelar' })} />)
  expect(screen.getByText('Quero cancelar')).toBeInTheDocument()
})

test('sem texto, descreve o anexo', async () => {
  const attachment = {
    id: 1,
    message_id: 1,
    file_type: 'image' as const,
    account_id: 1,
    extension: 'png',
    data_url: '',
    thumb_url: '',
    file_size: 10,
  }
  await renderWithI18n(
    <MessagePreview message={messageFixture({ content: null, attachments: [attachment] })} />,
  )
  expect(screen.getByText('Picture message')).toBeInTheDocument()
})

test('sem texto nem anexo, "No content available"', async () => {
  await renderWithI18n(<MessagePreview message={messageFixture({ content: '  ' })} />)
  expect(screen.getByText('No content available')).toBeInTheDocument()
})

test.each([
  [{ message_type: 1 as const }, 'outgoing'],
  [{ private: true }, 'private'],
  [{ message_type: 2 as const }, 'activity'],
])('marca o tipo da mensagem (%j)', async (overrides, kind) => {
  const { container } = await renderWithI18n(<MessagePreview message={messageFixture(overrides)} />)
  expect(container.querySelector(`[data-type="${kind}"]`)).toBeInTheDocument()
})
