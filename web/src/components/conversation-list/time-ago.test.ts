import { describe, expect, test } from 'vitest'

import { exactTimestamp, longTimeAgo, shortTimeAgo } from './time-ago'

const now = new Date('2026-09-30T12:00:00Z')
const ago = (seconds: number) => Math.floor(now.getTime() / 1000) - seconds
const MIN = 60
const HOUR = 3600
const DAY = 86_400

describe('shortTimeAgo (shortTimestamp do Chatwoot)', () => {
  test.each([
    [10, 'now'],
    [5 * MIN, '5m'],
    [44 * MIN, '44m'],
    [60 * MIN, '1h'],
    [5 * HOUR, '5h'],
    [23 * HOUR, '23h'],
    [30 * HOUR, '1d'],
    [3 * DAY, '3d'],
    [40 * DAY, '1mo'],
    [100 * DAY, '3mo'],
    [400 * DAY, '1y'],
  ])('%is atrás → %s', (seconds, expected) => {
    expect(shortTimeAgo(ago(seconds), now)).toBe(expected)
  })

  test('sem timestamp devolve vazio', () => {
    expect(shortTimeAgo(0, now)).toBe('')
    expect(shortTimeAgo(undefined, now)).toBe('')
  })
})

describe('longTimeAgo (formatDistanceToNow do date-fns)', () => {
  test.each([
    [10, 'less than a minute ago'],
    [60, '1 minute ago'],
    [5 * HOUR, 'about 5 hours ago'],
    [3 * DAY, '3 days ago'],
  ])('%is atrás → %s', (seconds, expected) => {
    expect(longTimeAgo(ago(seconds), now)).toBe(expected)
  })
})

test('exactTimestamp formata como o tooltip do Chatwoot', () => {
  expect(exactTimestamp(Date.UTC(2026, 8, 30, 15, 4) / 1000, 'UTC')).toBe('Sep 30 2026, 3:04 PM')
})
