import { useState } from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { Dialog } from './dialog'

function setup(open = true, type?: 'edit' | 'alert') {
  const onClose = vi.fn()
  const onConfirm = vi.fn()
  render(
    <Dialog
      open={open}
      type={type}
      title="Excluir?"
      description="Não dá para desfazer"
      confirmLabel="Excluir"
      cancelLabel="Cancelar"
      onClose={onClose}
      onConfirm={onConfirm}
    >
      <p>conteúdo</p>
    </Dialog>,
  )
  return { onClose, onConfirm }
}

test('fechado não renderiza nada', () => {
  setup(false)
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})

test('aberto mostra título, descrição e conteúdo, com nome acessível', () => {
  setup()
  expect(screen.getByRole('dialog', { name: 'Excluir?' })).toBeInTheDocument()
  expect(screen.getByText('Não dá para desfazer')).toBeInTheDocument()
  expect(screen.getByText('conteúdo')).toBeInTheDocument()
})

test('confirmar envia e fecha', async () => {
  const { onConfirm, onClose } = setup()
  await userEvent.click(screen.getByRole('button', { name: 'Excluir' }))
  expect(onConfirm).toHaveBeenCalledOnce()
  expect(onClose).toHaveBeenCalled()
})

test('cancelar, Esc e clique no fundo fecham sem confirmar', async () => {
  const { onConfirm, onClose } = setup()
  await userEvent.click(screen.getByRole('button', { name: 'Cancelar' }))
  await userEvent.keyboard('{Escape}')
  await userEvent.click(screen.getByTestId('dialog-backdrop'))
  expect(onClose).toHaveBeenCalledTimes(3)
  expect(onConfirm).not.toHaveBeenCalled()
})

test('clicar dentro do painel não fecha', async () => {
  const { onClose } = setup()
  await userEvent.click(screen.getByText('conteúdo'))
  expect(onClose).not.toHaveBeenCalled()
})

test('alert usa o botão de perigo', () => {
  setup(true, 'alert')
  expect(screen.getByRole('button', { name: 'Excluir' }).className).toMatch(/bg-n-ruby-9/)
})

test('devolve o foco a quem abriu', async () => {
  function Host() {
    return <Toggle />
  }
  function Toggle() {
    const [open, setOpen] = useState(false)
    return (
      <>
        <button onClick={() => setOpen(true)}>abrir</button>
        <Dialog
          open={open}
          onClose={() => setOpen(false)}
          onConfirm={() => {}}
          confirmLabel="ok"
          cancelLabel="cancelar"
        />
      </>
    )
  }
  render(<Host />)
  await userEvent.click(screen.getByRole('button', { name: 'abrir' }))
  await userEvent.keyboard('{Escape}')
  expect(screen.getByRole('button', { name: 'abrir' })).toHaveFocus()
})
