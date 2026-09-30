import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { Combobox } from './combobox'

const options = [
  { value: 'g', label: 'Grupo', disabled: true },
  { value: 'pt', label: 'Português' },
  { value: 'en', label: 'English' },
]

function setup(value: string | null = null) {
  const onChange = vi.fn()
  render(
    <Combobox
      id="lang"
      options={options}
      value={value}
      onChange={onChange}
      placeholder="Escolha"
      searchPlaceholder="Buscar"
      emptyState="Nada"
    />,
  )
  return { onChange }
}

test('mostra o placeholder e abre a lista', async () => {
  setup()
  expect(screen.queryByRole('listbox')).not.toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Escolha' }))
  expect(screen.getByRole('listbox')).toBeInTheDocument()
  expect(screen.getAllByRole('option')).toHaveLength(2)
})

test('foca a busca ao abrir', async () => {
  setup()
  await userEvent.click(screen.getByRole('button', { name: 'Escolha' }))
  expect(screen.getByRole('searchbox')).toHaveFocus()
})

test('mostra o rótulo do valor e marca a opção', async () => {
  setup('pt')
  await userEvent.click(screen.getByRole('button', { name: 'Português' }))
  expect(screen.getByRole('option', { name: 'Português' })).toHaveAttribute('aria-selected', 'true')
  expect(screen.getByRole('option', { name: 'English' })).toHaveAttribute('aria-selected', 'false')
})

test('escolher chama onChange e fecha', async () => {
  const { onChange } = setup()
  await userEvent.click(screen.getByRole('button', { name: 'Escolha' }))
  await userEvent.click(screen.getByRole('option', { name: 'English' }))
  expect(onChange).toHaveBeenCalledWith('en')
  expect(screen.queryByRole('listbox')).not.toBeInTheDocument()
})

test('busca filtra e esconde os grupos', async () => {
  setup()
  await userEvent.click(screen.getByRole('button', { name: 'Escolha' }))
  await userEvent.type(screen.getByRole('searchbox'), 'eng')
  expect(screen.getAllByRole('option')).toHaveLength(1)
  expect(screen.queryByText('Grupo')).not.toBeInTheDocument()
  await userEvent.clear(screen.getByRole('searchbox'))
  await userEvent.type(screen.getByRole('searchbox'), 'zzz')
  expect(screen.getByText('Nada')).toBeInTheDocument()
})

test('teclado: setas e Enter escolhem', async () => {
  const { onChange } = setup()
  await userEvent.click(screen.getByRole('button', { name: 'Escolha' }))
  await userEvent.keyboard('{ArrowDown}{ArrowDown}{Enter}')
  expect(onChange).toHaveBeenCalledWith('en')
})

test('Esc e clique fora fecham', async () => {
  setup()
  await userEvent.click(screen.getByRole('button', { name: 'Escolha' }))
  await userEvent.keyboard('{Escape}')
  expect(screen.queryByRole('listbox')).not.toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Escolha' }))
  await userEvent.click(document.body)
  expect(screen.queryByRole('listbox')).not.toBeInTheDocument()
})
