// Pastas (filtros salvos): api/v1/accounts/custom_filters_controller.rb, como dashboard/api/customViews.js.
import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { CustomFilter, FilterCondition } from './types'

type FilterType = CustomFilter['filter_type']

const base = (accountId: number) => `/api/v1/accounts/${accountId}/custom_filters`

export const customFilterKeys = {
  all: (accountId: number) => ['accounts', accountId, 'custom_filters'] as const,
  list: (accountId: number, filterType: FilterType) =>
    [...customFilterKeys.all(accountId), filterType] as const,
}

export const customFiltersQuery = (accountId: number, filterType: FilterType = 'conversation') =>
  queryOptions({
    queryKey: customFilterKeys.list(accountId, filterType),
    queryFn: () => api.get<CustomFilter[]>(`${base(accountId)}?filter_type=${filterType}`),
  })

export type CustomFilterInput = {
  name: string
  /** O dashboard do Chatwoot manda o número do enum (0 conversa, 1 contato); a API aceita os dois. */
  filter_type?: FilterType | 0 | 1
  query: { payload: FilterCondition[] }
}

export const createCustomFilter = (accountId: number, input: CustomFilterInput) =>
  api.post<CustomFilter>(base(accountId), { custom_filter: input })

export const updateCustomFilter = (
  accountId: number,
  id: number,
  input: Partial<CustomFilterInput>,
) => api.patch<CustomFilter>(`${base(accountId)}/${id}`, { custom_filter: input })

export const deleteCustomFilter = (accountId: number, id: number) =>
  api.delete<void>(`${base(accountId)}/${id}`)
