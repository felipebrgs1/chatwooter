import { render } from '@testing-library/react'
import { expect, test } from 'vitest'

import { ChannelIcon } from './channel-icon'

const html = (channel: string) => render(<ChannelIcon channel={channel} />).container.innerHTML

test('cada canal tem seu ícone', () => {
  expect(html('telegram')).not.toBe(html('whatsapp'))
})

test('aceita o formato do Chatwoot (Channel::Telegram)', () => {
  expect(html('Channel::Telegram')).toBe(html('telegram'))
})

test('canal desconhecido usa o ícone genérico', () => {
  expect(html('email')).not.toBe(html('telegram'))
  expect(html('email')).toBe(html('sms'))
})

test('é decorativo', () => {
  expect(render(<ChannelIcon channel="telegram" />).container.querySelector('svg')).toHaveAttribute(
    'aria-hidden',
    'true',
  )
})
