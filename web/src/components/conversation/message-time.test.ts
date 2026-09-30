import { expect, test } from 'vitest'

import { messageTimestamp } from './message-time'

test('formata epoch em segundos como "LLL d, h:mm a" (en)', () => {
  // 2026-09-30 15:04 UTC
  const epoch = Date.UTC(2026, 8, 30, 15, 4) / 1000
  expect(messageTimestamp(epoch, 'en', 'UTC')).toBe('Sep 30, 3:04 PM')
})

test('respeita o idioma', () => {
  const epoch = Date.UTC(2026, 8, 30, 15, 4) / 1000
  expect(messageTimestamp(epoch, 'pt_BR', 'UTC')).toMatch(/30/)
})
