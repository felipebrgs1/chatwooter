import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { Composer } from './composer'
import { renderConversation } from './test-utils'

async function setup(props: Partial<Parameters<typeof Composer>[0]> = {}) {
  const onSend = vi.fn()
  await renderConversation(<Composer canReply onSend={onSend} {...props} />)
  return { onSend, user: userEvent.setup() }
}

const reply = () => screen.getByPlaceholderText(/Shift \+ enter for new line. Start with/)

test('Enter envia e limpa o campo', async () => {
  const { onSend, user } = await setup()
  await user.type(reply(), 'Olá{Enter}')
  expect(onSend).toHaveBeenCalledWith('Olá', false)
  expect(reply()).toHaveValue('')
})

test('Shift+Enter quebra a linha sem enviar', async () => {
  const { onSend, user } = await setup()
  await user.type(reply(), 'a{Shift>}{Enter}{/Shift}b')
  expect(onSend).not.toHaveBeenCalled()
  expect(reply()).toHaveValue('a\nb')
})

test('botão Send envia e fica desabilitado com campo vazio ou só espaços', async () => {
  const { onSend, user } = await setup()
  const send = screen.getByRole('button', { name: 'Send' })
  expect(send).toBeDisabled()
  await user.type(reply(), '   ')
  expect(send).toBeDisabled()
  await user.type(reply(), 'oi')
  await user.click(send)
  expect(onSend).toHaveBeenCalledWith('oi', false)
})

test('nota privada: muda placeholder e botão, e envia como privada', async () => {
  const { onSend, user } = await setup()
  await user.click(screen.getByRole('button', { name: 'Private Note' }))
  const field = screen.getByPlaceholderText(/This will be visible only to Agents/)
  expect(screen.getByRole('button', { name: 'Add Note' })).toBeDisabled()
  await user.type(field, 'interno')
  await user.click(screen.getByRole('button', { name: 'Add Note' }))
  expect(onSend).toHaveBeenCalledWith('interno', true)
})

test('alternar entre Reply e Private Note mantém o texto digitado', async () => {
  const { user } = await setup()
  await user.type(reply(), 'rascunho')
  await user.click(screen.getByRole('button', { name: 'Private Note' }))
  expect(screen.getByPlaceholderText(/visible only to Agents/)).toHaveValue('rascunho')
})

test('sem can_reply: só nota privada, com aviso', async () => {
  const { onSend, user } = await setup({ canReply: false })
  expect(screen.getByText('You cannot reply to this conversation')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Reply' })).toBeDisabled()
  await user.type(screen.getByPlaceholderText(/visible only to Agents/), 'nota{Enter}')
  expect(onSend).toHaveBeenCalledWith('nota', true)
})

test('o campo cresce com o conteúdo', async () => {
  const { user } = await setup()
  const field = reply() as HTMLTextAreaElement
  Object.defineProperty(field, 'scrollHeight', { configurable: true, value: 120 })
  await user.type(field, 'x')
  expect(field.style.height).toBe('120px')
})
