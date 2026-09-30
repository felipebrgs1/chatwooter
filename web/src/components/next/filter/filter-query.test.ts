import { expect, test } from 'vitest'

import {
  generatePayload,
  initialFiltersFromView,
  parseRouteFilters,
  rowFromCondition,
  validateSingleFilter,
  type FilterRow,
} from './filter-query'

const row = (overrides: Partial<FilterRow>): FilterRow => ({
  attribute_key: 'status',
  filter_operator: 'equal_to',
  values: [],
  query_operator: 'and',
  ...overrides,
})

test('generatePayload troca as opções pelos ids e tira o operador lógico da última condição', () => {
  const payload = generatePayload([
    row({ values: [{ id: 'open', name: 'Open' }] }),
    row({ attribute_key: 'inbox_id', values: { id: 3, name: 'Suporte' }, query_operator: 'or' }),
    row({ attribute_key: 'referer', filter_operator: 'contains', values: 'pricing' }),
  ])
  expect(payload).toEqual([
    {
      attribute_key: 'status',
      filter_operator: 'equal_to',
      values: ['open'],
      query_operator: 'and',
    },
    { attribute_key: 'inbox_id', filter_operator: 'equal_to', values: [3], query_operator: 'or' },
    { attribute_key: 'referer', filter_operator: 'contains', values: ['pricing'] },
  ])
})

test('generatePayload manda o fuso nas datas de timestamp', () => {
  const [condition] = generatePayload(
    [row({ attribute_key: 'created_at', filter_operator: 'is_less_than', values: '2024-01-31' })],
    { timezone: 'America/Sao_Paulo' },
  )
  expect(condition).toMatchObject({ values: ['2024-01-31'], timezone: 'America/Sao_Paulo' })
})

test('validateSingleFilter exige valor, menos em presença, e limita os dias', () => {
  expect(validateSingleFilter(row({ values: [] }))).toBe('VALUE_REQUIRED')
  expect(validateSingleFilter(row({ values: {} }))).toBe('VALUE_REQUIRED')
  expect(validateSingleFilter(row({ filter_operator: 'is_present', values: [] }))).toBeNull()
  expect(
    validateSingleFilter(
      row({ attribute_key: 'created_at', filter_operator: 'days_before', values: '999' }),
    ),
  ).toBe('VALUE_MUST_BE_BETWEEN_1_AND_998')
  expect(validateSingleFilter(row({ values: [{ id: 'open', name: 'Open' }] }))).toBeNull()
})

test('parseRouteFilters aceita só uma lista não vazia de condições válidas', () => {
  const valid = [{ attribute_key: 'status', filter_operator: 'equal_to', values: ['open'] }]
  expect(parseRouteFilters(JSON.stringify(valid))).toEqual(valid)
  expect(parseRouteFilters('[]')).toBeNull()
  expect(parseRouteFilters('lixo')).toBeNull()
  expect(parseRouteFilters(JSON.stringify([{ attribute_key: 'status', values: [] }]))).toBeNull()
})

test('rowFromCondition devolve as opções com nome para editar uma pasta', () => {
  const lists = {
    agents: [{ id: 7, name: 'Ana' }],
    inboxes: [{ id: 3, name: 'Suporte' }],
    teams: [],
    labels: [{ title: 'vip' }, { title: 'spam' }],
  }
  expect(
    rowFromCondition(
      { attribute_key: 'assignee_id', filter_operator: 'equal_to', values: [7] },
      lists,
    ),
  ).toMatchObject({ values: { id: 7, name: 'Ana' }, query_operator: 'and' })
  expect(
    rowFromCondition({ attribute_key: 'team_id', filter_operator: 'equal_to', values: [9] }, lists)
      .values,
  ).toEqual({ id: 9, name: 9 })
  expect(
    rowFromCondition(
      { attribute_key: 'labels', filter_operator: 'equal_to', values: ['vip'] },
      lists,
    ).values,
  ).toEqual([{ id: 'vip', name: 'vip' }])
  expect(
    rowFromCondition(
      { attribute_key: 'status', filter_operator: 'equal_to', values: ['open'] },
      lists,
    ).values,
  ).toEqual([{ id: 'open', name: 'open' }])
  expect(
    rowFromCondition(
      {
        attribute_key: 'created_at',
        filter_operator: 'days_before',
        values: [30],
        query_operator: 'or',
      },
      lists,
    ),
  ).toMatchObject({ values: '30', query_operator: 'or' })
})

test('initialFiltersFromView abre o modal com o status e a visão atuais (useFilter)', () => {
  const rows = initialFiltersFromView(
    { status: 'pending', inbox_id: 3, team_id: 2, label: 'vip' },
    { statusName: 'Pending', inbox: { id: 3, name: 'Suporte' }, team: { id: 2, name: 'Vendas' } },
  )
  expect(rows.map((r) => [r.attribute_key, r.values])).toEqual([
    ['status', [{ id: 'pending', name: 'Pending' }]],
    ['inbox_id', [{ id: 3, name: 'Suporte' }]],
    ['team_id', { id: 2, name: 'Vendas' }],
    ['labels', [{ id: 'vip', name: 'vip' }]],
  ])
})
