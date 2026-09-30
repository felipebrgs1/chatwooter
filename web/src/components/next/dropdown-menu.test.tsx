import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { DropdownMenu } from './dropdown-menu'

const items = [
  { value: 1, label: 'Ana' },
  { value: 2, label: 'Bruno' },
]

function setup(
  props: Partial<React.ComponentProps<typeof DropdownMenu<(typeof items)[number]>>> = {},
) {
  const onSelect = vi.fn()
  const onClose = vi.fn()
  render(
    <DropdownMenu
      id="m"
      open
      items={items}
      onSelect={onSelect}
      onClose={onClose}
      searchPlaceholder="Buscar"
      emptyState="Nada"
      {...props}
    />,
  )
  return { onSelect, onClose }
}

test('fechado não renderiza', () => {
  setup({ open: false })
  expect(screen.queryByRole('searchbox')).not.toBeInTheDocument()
})

test('escolher um item avisa e fecha', async () => {
  const { onSelect, onClose } = setup()
  await userEvent.click(screen.getByRole('button', { name: 'Bruno' }))
  expect(onSelect).toHaveBeenCalledWith(2)
  expect(onClose).toHaveBeenCalled()
})

test('busca filtra e mostra o vazio', async () => {
  setup()
  await userEvent.type(screen.getByPlaceholderText('Buscar'), 'an')
  expect(screen.queryByRole('button', { name: 'Bruno' })).not.toBeInTheDocument()
  await userEvent.clear(screen.getByPlaceholderText('Buscar'))
  await userEvent.type(screen.getByPlaceholderText('Buscar'), 'zzz')
  expect(screen.getByText('Nada')).toBeInTheDocument()
})

test('destaca o selecionado e renderiza o slot do item', () => {
  setup({ selected: 1, renderItem: (i) => <em>({i.value})</em> })
  expect(screen.getByRole('button', { name: /Ana/ })).toHaveClass('bg-n-alpha-1')
  expect(screen.getByText('(2)')).toBeInTheDocument()
})
