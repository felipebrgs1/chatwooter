import { act, render, screen } from '@testing-library/react'
import { I18nextProvider } from 'react-i18next'
import { afterEach, expect, test, vi } from 'vitest'

import { conversationFixture } from '../../test/conversation-fixtures'
import { createI18n } from '../../i18n'
import { ConversationCard } from './conversation-card'
import { ConversationCardExpanded } from './conversation-card-expanded'

afterEach(() => vi.useRealTimers())

test.each([
  ['compacto', ConversationCard],
  ['expandido', ConversationCardExpanded],
] as const)('card %s atualiza os horários na tela sem refetch', async (_layout, Card) => {
  const i18n = await createI18n('en')
  const start = new Date('2026-09-30T12:00:00Z')
  vi.useFakeTimers()
  vi.setSystemTime(start)
  const activity = start.getTime() / 1000 - 300
  const conversation = conversationFixture({
    created_at: activity,
    last_activity_at: activity,
  })
  const { unmount: cleanup } = render(
    <I18nextProvider i18n={i18n}>
      <Card conversation={conversation} href="/app/conversations/1" />
    </I18nextProvider>,
  )
  expect(screen.getByText('5m • 5m')).toBeInTheDocument()
  act(() => vi.advanceTimersByTime(60_000))
  expect(screen.getByText('6m • 6m')).toBeInTheDocument()
  cleanup()
  expect(vi.getTimerCount()).toBe(0)
})
