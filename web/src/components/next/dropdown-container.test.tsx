import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test } from 'vitest'

import { DropdownContainer } from './dropdown-container'

function Demo() {
  return (
    <div>
      <DropdownContainer
        id="menu"
        trigger={({ toggle, open, triggerProps }) => (
          <button {...triggerProps} onClick={toggle} aria-expanded={open}>
            Abrir
          </button>
        )}
      >
        <p>corpo</p>
      </DropdownContainer>
      <span>fora</span>
    </div>
  )
}

test('começa fechado e abre pelo gatilho', async () => {
  render(<Demo />)
  expect(screen.queryByText('corpo')).not.toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Abrir' }))
  expect(screen.getByText('corpo')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Abrir' })).toHaveClass('bg-n-alpha-1')
})

test('clicar fora fecha', async () => {
  render(<Demo />)
  await userEvent.click(screen.getByRole('button', { name: 'Abrir' }))
  await userEvent.click(screen.getByText('fora'))
  expect(screen.queryByText('corpo')).not.toBeInTheDocument()
})

test('Esc fecha', async () => {
  render(<Demo />)
  await userEvent.click(screen.getByRole('button', { name: 'Abrir' }))
  await userEvent.keyboard('{Escape}')
  expect(screen.queryByText('corpo')).not.toBeInTheDocument()
})

test('clicar dentro não fecha', async () => {
  render(<Demo />)
  await userEvent.click(screen.getByRole('button', { name: 'Abrir' }))
  await userEvent.click(screen.getByText('corpo'))
  expect(screen.getByText('corpo')).toBeInTheDocument()
})
