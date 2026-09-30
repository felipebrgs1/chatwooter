import { act, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import { showAlert } from './alert'
import { Toaster } from './toaster'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())

test('mostra a mensagem recebida por showAlert', () => {
  render(<Toaster />)
  act(() => showAlert('Salvo'))
  expect(screen.getByText('Salvo')).toBeInTheDocument()
})

test('some depois da duração padrão de 2500ms', () => {
  render(<Toaster />)
  act(() => showAlert('Some logo'))
  act(() => vi.advanceTimersByTime(2499))
  expect(screen.getByText('Some logo')).toBeInTheDocument()
  act(() => vi.advanceTimersByTime(1))
  expect(screen.queryByText('Some logo')).not.toBeInTheDocument()
})

test('duração customizada e várias mensagens empilhadas', () => {
  render(<Toaster />)
  act(() => {
    showAlert('Curta', { duration: 1000 })
    showAlert('Longa', { duration: 6000 })
  })
  expect(screen.getAllByRole('status')).toHaveLength(2)
  act(() => vi.advanceTimersByTime(1000))
  expect(screen.queryByText('Curta')).not.toBeInTheDocument()
  expect(screen.getByText('Longa')).toBeInTheDocument()
})

test('anuncia a mensagem para leitores de tela', () => {
  render(<Toaster />)
  act(() => showAlert('Erro ao entrar'))
  expect(screen.getByRole('status')).toHaveTextContent('Erro ao entrar')
})
