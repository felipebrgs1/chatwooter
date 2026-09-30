import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import { shortTimeAgo } from '../../shared/time-ago'
import { useTimeAgo } from './use-time-ago'

const start = new Date('2026-09-30T12:00:00Z')
const timestamp = start.getTime() / 1000

beforeEach(() => {
  vi.useFakeTimers()
  vi.setSystemTime(start)
})
afterEach(() => vi.useRealTimers())

test.each([
  [30, 60_000],
  [3600, 60_000],
  [3601, 3_600_000],
  [86400, 3_600_000],
  [86401, 86_400_000],
])('atividade há %is atualiza depois de %ims', (age, interval) => {
  const { result } = renderHook(() => useTimeAgo(timestamp - age, 1))
  act(() => vi.advanceTimersByTime(interval - 1))
  expect(result.current).toEqual(start)
  act(() => vi.advanceTimersByTime(1))
  expect(result.current.getTime()).toBe(start.getTime() + interval)
})

test('atualiza o texto relativo sem receber novos dados da API', () => {
  const { result } = renderHook(() => useTimeAgo(timestamp - 300, 1))
  expect(shortTimeAgo(timestamp - 300, result.current)).toBe('5m')
  act(() => vi.advanceTimersByTime(60_000))
  expect(shortTimeAgo(timestamp - 300, result.current)).toBe('6m')
})

test('recalcula o intervalo ao receber atividade nova ou reciclar a conversa', () => {
  const { result, rerender, unmount } = renderHook(({ activity, id }) => useTimeAgo(activity, id), {
    initialProps: { activity: timestamp - 90000, id: 1 },
  })
  act(() => vi.advanceTimersByTime(60_000))
  rerender({ activity: timestamp, id: 2 })
  expect(result.current.getTime()).toBe(start.getTime() + 60_000)
  act(() => vi.advanceTimersByTime(60_000))
  expect(result.current.getTime()).toBe(start.getTime() + 120_000)
  expect(vi.getTimerCount()).toBe(1)
  unmount()
  expect(vi.getTimerCount()).toBe(0)
})
