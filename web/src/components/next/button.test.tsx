import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { Button } from './button'

test('renderiza o rótulo e dispara o clique', async () => {
  const onClick = vi.fn()
  render(<Button label="Salvar" onClick={onClick} />)
  await userEvent.click(screen.getByRole('button', { name: 'Salvar' }))
  expect(onClick).toHaveBeenCalledOnce()
})

test('type padrão é button', () => {
  render(<Button label="x" />)
  expect(screen.getByRole('button')).toHaveAttribute('type', 'button')
})

test('só ícone usa o tamanho quadrado', () => {
  render(<Button icon="ph-check" size="sm" aria-label="ok" />)
  expect(screen.getByRole('button', { name: 'ok' })).toHaveClass('h-8', 'w-8')
})

test('variante e cor escolhem as classes', () => {
  render(<Button label="x" color="ruby" variant="faded" />)
  expect(screen.getByRole('button').className).toMatch(/bg-n-ruby-9\/10/)
})

test('trailingIcon inverte a ordem', () => {
  render(<Button label="x" icon="ph-check" trailingIcon />)
  expect(screen.getByRole('button')).toHaveClass('flex-row-reverse')
})

test('disabled bloqueia o clique', async () => {
  const onClick = vi.fn()
  render(<Button label="x" disabled onClick={onClick} />)
  await userEvent.click(screen.getByRole('button'))
  expect(onClick).not.toHaveBeenCalled()
})
