import { render, screen } from '@testing-library/react'
import { expect, test } from 'vitest'

import { Avatar } from './avatar'
import { initials } from './initials'

test('mostra as iniciais das duas primeiras palavras', () => {
  render(<Avatar name="ana maria silva" />)
  expect(screen.getByRole('img')).toHaveTextContent('AM')
})

test('sem nome cai para o ícone de usuário', () => {
  const { container } = render(<Avatar />)
  expect(screen.getByRole('img')).toHaveTextContent('')
  expect(container.querySelector('svg')).toBeInTheDocument()
})

test('a cor depende do tamanho do nome', () => {
  render(<Avatar name="Ana" />)
  expect(screen.getByRole('img').className).toMatch(/bg-avatar-3-bg/)
})

test('o raio e as dimensões seguem o tamanho', () => {
  const { container } = render(<Avatar name="Ana" size={48} />)
  expect(screen.getByRole('img')).toHaveClass('rounded-xl')
  expect(container.firstChild).toHaveStyle({ width: '48px', height: '48px' })
})

test('status aparece como selo', () => {
  const { container } = render(<Avatar name="Ana" status="online" />)
  expect(container.querySelector('[data-status="online"]')).toBeInTheDocument()
})

test('initials tolera espaços extras', () => {
  expect(initials('  joão   paulo  ')).toBe('JP')
})
