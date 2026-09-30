import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { TabBar } from './tab-bar'

const tabs = [
  { value: 'mine', label: 'Mine', count: 3 },
  { value: 'unassigned', label: 'Unassigned' },
  { value: 'all', label: 'All' },
]

test('marca a aba ativa e mostra a contagem', () => {
  render(<TabBar id="t" tabs={tabs} active="unassigned" onChange={() => {}} />)
  expect(screen.getByRole('tab', { name: 'Unassigned' })).toHaveAttribute('aria-selected', 'true')
  expect(screen.getByRole('tab', { name: 'Mine (3)' })).toHaveAttribute('aria-selected', 'false')
})

test('clicar troca de aba', async () => {
  const onChange = vi.fn()
  render(<TabBar id="t" tabs={tabs} active="mine" onChange={onChange} />)
  await userEvent.click(screen.getByRole('tab', { name: 'All' }))
  expect(onChange).toHaveBeenCalledWith('all')
})

test('setas movem entre abas', async () => {
  const onChange = vi.fn()
  render(<TabBar id="t" tabs={tabs} active="mine" onChange={onChange} />)
  screen.getByRole('tab', { name: 'Mine (3)' }).focus()
  await userEvent.keyboard('{ArrowRight}')
  expect(onChange).toHaveBeenCalledWith('unassigned')
})
