import { describe, expect, test } from 'vitest'

import { messageFixture } from '../../test/conversation-fixtures'
import { groupsWithNext, orientationOf, variantOf, type ThreadMessage } from './message-variant'

const agent = { id: 7, name: 'Ana', type: 'user' as const }
const contact = { id: 100, name: 'Maria', type: 'contact' as const }
const msg = (o: Partial<ThreadMessage> = {}): ThreadMessage =>
  ({ ...messageFixture(), ...o }) as ThreadMessage

describe('variantOf', () => {
  test('nota privada vence tudo', () => {
    expect(variantOf(msg({ private: true, message_type: 1, status: 'failed' }))).toBe('private')
  })
  test('falha de envio é erro', () => {
    expect(variantOf(msg({ message_type: 1, status: 'failed', sender: agent }))).toBe('error')
  })
  test('por tipo: entrada, saída, atividade, template', () => {
    expect(variantOf(msg({ message_type: 0 }))).toBe('user')
    expect(variantOf(msg({ message_type: 1, sender: agent }))).toBe('agent')
    expect(variantOf(msg({ message_type: 2 }))).toBe('activity')
    expect(variantOf(msg({ message_type: 3, sender: agent }))).toBe('template')
  })
  test('saída sem remetente ou de agent_bot é bot', () => {
    expect(variantOf(msg({ message_type: 1, sender: undefined }))).toBe('bot')
    expect(
      variantOf(msg({ message_type: 1, sender: { id: 1, name: 'B', type: 'agent_bot' } })),
    ).toBe('bot')
  })
  test('mensagem pendente é do agente mesmo sem remetente', () => {
    expect(variantOf(msg({ message_type: 1, sender: undefined, status: 'progress' }))).toBe('agent')
  })
})

describe('orientationOf', () => {
  test('cliente à esquerda; agente, bot e pendentes à direita; atividade ao centro', () => {
    expect(orientationOf(msg({ message_type: 0, sender: contact }))).toBe('left')
    expect(orientationOf(msg({ message_type: 1, sender: agent }))).toBe('right')
    expect(orientationOf(msg({ message_type: 1, sender: undefined }))).toBe('right')
    expect(orientationOf(msg({ message_type: 2 }))).toBe('center')
  })
})

describe('groupsWithNext', () => {
  const t = 1_790_000_000
  const a = msg({ id: 1, created_at: t, sender: contact })
  test('mesmo remetente, tipo e minuto agrupam', () => {
    expect(groupsWithNext(a, msg({ id: 2, created_at: t + 10, sender: contact }))).toBe(true)
  })
  test('outro remetente, outro tipo, outro minuto ou sem próxima não agrupam', () => {
    expect(groupsWithNext(a, msg({ id: 2, created_at: t + 10, sender: agent }))).toBe(false)
    expect(
      groupsWithNext(a, msg({ id: 2, created_at: t + 10, message_type: 1, sender: contact })),
    ).toBe(false)
    expect(groupsWithNext(a, msg({ id: 2, created_at: t + 120, sender: contact }))).toBe(false)
    expect(groupsWithNext(a, undefined)).toBe(false)
  })
  test('próxima com falha nunca agrupa', () => {
    expect(
      groupsWithNext(a, msg({ id: 2, created_at: t + 1, sender: contact, status: 'failed' })),
    ).toBe(false)
  })
})
