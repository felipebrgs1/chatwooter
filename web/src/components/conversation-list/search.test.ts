import { describe, expect, test } from 'vitest'

import { parseSearch, parseUrlSearch, toFilters, viewTitle } from './search'

describe('parseSearch', () => {
  test('sem parâmetros: abertas, minhas, mais recentes', () => {
    expect(parseSearch({})).toEqual({
      status: 'open',
      assignee_type: 'me',
      sort_by: 'last_activity_at_desc',
    })
  })

  test('aceita os parâmetros válidos (números vêm da URL como string ou número)', () => {
    expect(
      parseSearch({
        status: 'resolved',
        assignee_type: 'all',
        sort_by: 'unread',
        inbox_id: '3',
        team_id: 2,
        label: 'vip',
        conversation_type: 'mention',
      }),
    ).toEqual({
      status: 'resolved',
      assignee_type: 'all',
      sort_by: 'unread',
      inbox_id: 3,
      team_id: 2,
      label: 'vip',
      conversation_type: 'mention',
    })
  })

  test('ignora valores inválidos em vez de quebrar', () => {
    expect(
      parseSearch({
        status: 'lixo',
        assignee_type: 'assigned',
        sort_by: 'x',
        inbox_id: 'abc',
        team_id: -1,
        label: '',
        conversation_type: 'nada',
      }),
    ).toEqual({ status: 'open', assignee_type: 'me', sort_by: 'last_activity_at_desc' })
  })
})

describe('toFilters', () => {
  test('converte a URL nos filtros da API', () => {
    expect(
      toFilters({
        status: 'open',
        assignee_type: 'me',
        sort_by: 'last_activity_at_desc',
        label: 'vip',
        team_id: 2,
      }),
    ).toEqual({
      status: 'open',
      assignee_type: 'me',
      sort_by: 'last_activity_at_desc',
      labels: ['vip'],
      team_id: 2,
    })
  })
})

describe('viewTitle', () => {
  const base = { status: 'open', assignee_type: 'me', sort_by: 'last_activity_at_desc' } as const
  test.each([
    [{ ...base }, { key: 'CHAT_LIST.TAB_HEADING' }],
    [{ ...base, conversation_type: 'mention' as const }, { key: 'CHAT_LIST.MENTION_HEADING' }],
    [
      { ...base, conversation_type: 'unattended' as const },
      { key: 'CHAT_LIST.UNATTENDED_HEADING' },
    ],
    [
      { ...base, conversation_type: 'participating' as const },
      { key: 'SIDEBAR.PARTICIPATING_CONVERSATIONS' },
    ],
    [{ ...base, label: 'vip' }, { text: '#vip' }],
  ])('%j', (search, expected) => {
    expect(viewTitle(search)).toEqual(expected)
  })
})

test('o nome da inbox vence o do time, que vence a etiqueta (pageTitle do ChatList.vue)', () => {
  const search = parseSearch({ inbox_id: 3, team_id: 2, label: 'vip' })
  expect(viewTitle(search, { inbox: 'Suporte', team: 'Vendas' })).toEqual({ text: 'Suporte' })
  expect(viewTitle(search, { team: 'Vendas' })).toEqual({ text: 'Vendas' })
  expect(viewTitle(search, {})).toEqual({ text: '#vip' })
})

test('etiqueta numérica (o roteador a lê como número) continua valendo', () => {
  expect(parseUrlSearch({ label: 123 })).toEqual({ label: '123' })
})

test('pasta e filtros avançados vêm da URL e não viram parâmetros da lista', () => {
  const condition = { attribute_key: 'status', filter_operator: 'equal_to', values: ['open'] }
  const fromString = parseUrlSearch({ folder_id: '5', filters: JSON.stringify([condition]) })
  expect(fromString).toEqual({ folder_id: 5, filters: [condition] })
  // o roteador já entrega o JSON da URL como lista
  expect(parseUrlSearch({ filters: [condition] }).filters).toEqual([condition])
  expect(parseUrlSearch({ folder_id: 'x', filters: '[]' })).toEqual({})
  expect(toFilters(parseSearch({ folder_id: 5, filters: [condition] }))).not.toHaveProperty(
    'folder_id',
  )
  expect(toFilters(parseSearch({ folder_id: 5, filters: [condition] }))).not.toHaveProperty(
    'filters',
  )
})
