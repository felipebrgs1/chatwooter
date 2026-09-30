// Conversões do filtro avançado entre o modal e a API: helper/filterQueryGenerator.js,
// helper/validations.js (validateSingleFilter, parseRouteFilters), helper/customViewsHelper.js
// (generateValuesForEditCustomViews) e shared/composables/useFilter.js (filtros iniciais do modal).
import type { FilterCondition } from '../../../api/types'

export type FilterOption = { id: string | number | boolean; name: string | number }
export type FilterValue = string | FilterOption | FilterOption[] | Record<string, never> | null

/** Uma linha do modal (ConditionRow): os valores ainda são as opções escolhidas, com nome. */
export type FilterRow = {
  attribute_key: string
  filter_operator: string
  values: FilterValue
  query_operator: 'and' | 'or'
  custom_attribute_type?: string
}

export type InputType =
  | 'multiSelect'
  | 'searchSelect'
  | 'asyncSearchSelect'
  | 'booleanSelect'
  | 'plainText'
  | 'number'
  | 'date'

export const DEFAULT_FILTER: FilterRow = {
  attribute_key: 'status',
  filter_operator: 'equal_to',
  values: [],
  query_operator: 'and',
}

/** Tipo de campo de cada atributo padrão (filter/provider.js). */
export const STANDARD_INPUT_TYPES: Record<string, InputType> = {
  status: 'multiSelect',
  priority: 'multiSelect',
  assignee_id: 'searchSelect',
  inbox_id: 'searchSelect',
  team_id: 'searchSelect',
  contact_id: 'asyncSearchSelect',
  display_id: 'number',
  campaign_id: 'searchSelect',
  labels: 'multiSelect',
  browser_language: 'searchSelect',
  referer: 'plainText',
  created_at: 'date',
  last_activity_at: 'date',
}

const NO_INPUT_OPERATORS = ['is_present', 'is_not_present']
const TIMESTAMP_ATTRIBUTES = ['created_at', 'last_activity_at']

/** operators.js: days_before troca o campo de data por texto. */
export function inputTypeFor(attributeKey: string, operator: string): InputType {
  if (operator === 'days_before') return 'plainText'
  return STANDARD_INPUT_TYPES[attributeKey] ?? 'plainText'
}

export function operatorHasInput(operator: string) {
  return !NO_INPUT_OPERATORS.includes(operator)
}

export type FilterError =
  | 'ATTRIBUTE_KEY_REQUIRED'
  | 'FILTER_OPERATOR_REQUIRED'
  | 'VALUE_REQUIRED'
  | 'VALUE_MUST_BE_BETWEEN_1_AND_998'

function isEmptyValue(value: unknown) {
  if (value === null || value === undefined || value === '') return true
  if (Array.isArray(value)) return !value.length
  if (typeof value === 'object') return !Object.keys(value).length
  return false
}

type ValidatableFilter = { attribute_key?: string; filter_operator?: string; values?: unknown }

export function validateSingleFilter(filter: ValidatableFilter): FilterError | null {
  if (!filter.attribute_key) return 'ATTRIBUTE_KEY_REQUIRED'
  if (!filter.filter_operator) return 'FILTER_OPERATOR_REQUIRED'
  if (operatorHasInput(filter.filter_operator) && isEmptyValue(filter.values))
    return 'VALUE_REQUIRED'
  if (filter.filter_operator === 'days_before') {
    const days = parseInt(String(filter.values), 10)
    if (days <= 0 || days >= 999) return 'VALUE_MUST_BE_BETWEEN_1_AND_998'
  }
  return null
}

function generateValues(values: FilterValue): FilterCondition['values'] {
  if (values === null || values === undefined || values === '') return []
  if (Array.isArray(values)) return values.map((v) => v.id)
  if (typeof values === 'object') return 'id' in values ? [values.id as FilterOption['id']] : []
  return [values]
}

/** filterQueryGenerator: o que vai para POST /conversations/filter e para a query da pasta. */
export function generatePayload(
  rows: FilterRow[],
  { timezone = Intl.DateTimeFormat().resolvedOptions().timeZone }: { timezone?: string } = {},
): FilterCondition[] {
  return rows.map((row, index) => {
    const condition: FilterCondition = {
      attribute_key: row.attribute_key,
      filter_operator: row.filter_operator,
      values: generateValues(row.values),
    }
    // a última condição não leva operador lógico: a API recusa um AND/OR sobrando no fim
    if (index < rows.length - 1) condition.query_operator = row.query_operator
    if (row.custom_attribute_type) condition.custom_attribute_type = row.custom_attribute_type
    if (TIMESTAMP_ATTRIBUTES.includes(row.attribute_key)) condition.timezone = timezone
    return condition
  })
}

const isFilterCondition = (value: unknown): value is FilterCondition =>
  !!value && typeof value === 'object' && !validateSingleFilter(value as ValidatableFilter)

/** Filtros aplicados que chegam pela URL (`?filters=`): lista não vazia de condições válidas, senão null. */
export function parseRouteFilters(serialized: string): FilterCondition[] | null {
  let filters: unknown
  try {
    filters = JSON.parse(serialized)
  } catch {
    return null
  }
  return Array.isArray(filters) && filters.length > 0 && filters.every(isFilterCondition)
    ? filters
    : null
}

/** Listas da conta que dão nome aos ids salvos (setParamsForEditFolderModal). */
export type FilterLists = {
  agents?: { id: number; name: string }[]
  inboxes?: { id: number; name: string }[]
  teams?: { id: number; name: string }[]
  labels?: { title: string }[]
  languages?: { id: string; name: string }[]
  priorities?: FilterOption[]
}

function named(
  values: FilterCondition['values'],
  list: { id: number | string; name: string }[] = [],
) {
  const item = list.find((entry) => entry.id === values[0])
  return { id: values[0], name: item ? item.name : (values[0] as string | number) }
}

// getValuesForFilter: ids salvos → opções com nome
function valuesForFilter(condition: FilterCondition, lists: FilterLists): FilterValue {
  const { attribute_key: key, values } = condition
  switch (key) {
    case 'status':
      return values.map((value) => ({ id: value, name: value as string }))
    case 'assignee_id':
      return named(values, lists.agents)
    case 'inbox_id':
      return named(values, lists.inboxes)
    case 'team_id':
      return named(values, lists.teams)
    case 'contact_id':
      return { id: values[0], name: `Contact #${values[0]}` }
    case 'labels':
      return (lists.labels ?? [])
        .filter((label) => values.includes(label.title))
        .map(({ title }) => ({ id: title, name: title }))
    case 'priority':
      return (lists.priorities ?? []).filter((option) => values.includes(option.id))
    case 'browser_language':
      return named(values, lists.languages)
    default:
      return { id: values[0], name: values[0] as string }
  }
}

/** generateValuesForEditCustomViews: uma condição salva (pasta ou URL) volta a ser linha do modal. */
export function rowFromCondition(condition: FilterCondition, lists: FilterLists): FilterRow {
  const type = STANDARD_INPUT_TYPES[condition.attribute_key]
  const values = condition.values ?? []
  let rowValues: FilterValue = values.length ? String(values[0]) : ''
  if (!operatorHasInput(condition.filter_operator)) rowValues = []
  else if (
    condition.filter_operator !== 'days_before' &&
    (type === 'multiSelect' || type === 'searchSelect' || type === 'asyncSearchSelect')
  )
    rowValues = valuesForFilter(condition, lists)

  return {
    attribute_key: condition.attribute_key,
    filter_operator: condition.filter_operator,
    values: rowValues,
    query_operator: condition.query_operator ?? 'and',
    ...(condition.custom_attribute_type
      ? { custom_attribute_type: condition.custom_attribute_type }
      : {}),
  }
}

type View = { status: string; inbox_id?: number; team_id?: number; label?: string }
type ViewNames = { statusName: string; inbox?: FilterOption; team?: FilterOption }

/** initializeExistingFilterToModal: o modal abre com o status e a inbox/time/etiqueta da visão atual. */
export function initialFiltersFromView(view: View, names: ViewNames): FilterRow[] {
  const base = { filter_operator: 'equal_to', query_operator: 'and' as const }
  const rows: FilterRow[] = [
    { ...base, attribute_key: 'status', values: [{ id: view.status, name: names.statusName }] },
  ]
  if (view.inbox_id)
    rows.push({
      ...base,
      attribute_key: 'inbox_id',
      values: [{ id: view.inbox_id, name: names.inbox?.name ?? view.inbox_id }],
    })
  if (view.team_id && names.team)
    rows.push({ ...base, attribute_key: 'team_id', values: names.team })
  if (view.label)
    rows.push({ ...base, attribute_key: 'labels', values: [{ id: view.label, name: view.label }] })
  return rows
}
