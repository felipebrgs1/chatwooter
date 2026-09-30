import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { Switch } from './switch'

test('alterna e avisa o novo valor', async () => {
  const onChange = vi.fn()
  render(<Switch id="s" checked={false} onChange={onChange} label="Notificações" />)
  const sw = screen.getByRole('switch', { name: 'Notificações' })
  expect(sw).toHaveAttribute('aria-checked', 'false')
  await userEvent.click(sw)
  expect(onChange).toHaveBeenCalledWith(true)
})

test('ligado vira false ao clicar', async () => {
  const onChange = vi.fn()
  render(<Switch id="s" checked onChange={onChange} label="x" />)
  await userEvent.click(screen.getByRole('switch'))
  expect(onChange).toHaveBeenCalledWith(false)
})

test('disabled não dispara', async () => {
  const onChange = vi.fn()
  render(<Switch id="s" checked={false} onChange={onChange} label="x" disabled />)
  await userEvent.click(screen.getByRole('switch'))
  expect(onChange).not.toHaveBeenCalled()
})
