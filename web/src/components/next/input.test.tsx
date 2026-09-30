import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { Input } from './input'

test('o rótulo fica ligado ao campo', () => {
  render(<Input label="E-mail" placeholder="voce@exemplo.com" />)
  expect(screen.getByLabelText('E-mail')).toHaveAttribute('placeholder', 'voce@exemplo.com')
})

test('digitar chama onChange', async () => {
  const onChange = vi.fn()
  render(<Input label="Nome" value="" onChange={onChange} />)
  await userEvent.type(screen.getByLabelText('Nome'), 'a')
  expect(onChange).toHaveBeenCalled()
})

test('mensagem de erro marca o campo como inválido', () => {
  render(<Input label="Nome" message="Obrigatório" messageType="error" />)
  expect(screen.getByLabelText('Nome')).toHaveAttribute('aria-invalid', 'true')
  expect(screen.getByLabelText('Nome')).toHaveAccessibleDescription('Obrigatório')
})

test('tamanho sm usa h-8', () => {
  render(<Input label="x" size="sm" />)
  expect(screen.getByLabelText('x')).toHaveClass('h-8')
})
