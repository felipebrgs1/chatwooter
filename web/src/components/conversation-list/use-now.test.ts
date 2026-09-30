import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import { useNow } from './use-now'

beforeEach(() => vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'Date'] }))
afterEach(() => vi.useRealTimers())

test('devolve a hora atual e se atualiza sozinho a cada intervalo', () => {
  vi.setSystemTime(new Date('2026-09-30T12:00:00Z'))
  const { result } = renderHook(() => useNow(60_000))
  expect(result.current.toISOString()).toBe('2026-09-30T12:00:00.000Z')

  act(() => vi.advanceTimersByTime(60_000))
  expect(result.current.toISOString()).toBe('2026-09-30T12:01:00.000Z')
})

test('para de atualizar quando o componente sai da tela', () => {
  const { unmount } = renderHook(() => useNow(1000))
  unmount()
  expect(vi.getTimerCount()).toBe(0)
})
