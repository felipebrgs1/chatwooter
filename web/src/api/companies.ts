import { queryOptions } from '@tanstack/react-query'

import { api } from './client'

export type Company = {
  id: number
  name: string
  domain: string | null
  description: string | null
  contacts_count: number | null
  custom_attributes: Record<string, unknown>
  avatar_url: string
  last_activity_at?: number
  created_at: number
  updated_at: number
}
export type CompanyInput = { name: string; domain: string | null; description: string | null }
export type CompanySearch = { page: number; search: string; sort: string }
export const companyKeys = {
  all: (accountId: number) => ['accounts', accountId, 'companies'] as const,
}

export function companiesQuery(accountId: number, { page, search, sort }: CompanySearch) {
  const params = new URLSearchParams({ page: String(page), sort })
  if (search) params.set('q', search)
  return queryOptions({
    queryKey: [...companyKeys.all(accountId), 'list', { page, search, sort }],
    queryFn: () =>
      api.get<{ meta: { total_count: number; page: string | number }; payload: Company[] }>(
        `/api/v1/accounts/${accountId}/companies${search ? '/search' : ''}?${params}`,
      ),
  })
}
export const companyQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: [...companyKeys.all(accountId), 'detail', id],
    queryFn: async () =>
      (await api.get<{ payload: Company }>(`/api/v1/accounts/${accountId}/companies/${id}`))
        .payload,
  })
export const createCompany = async (accountId: number, company: CompanyInput) =>
  (await api.post<{ payload: Company }>(`/api/v1/accounts/${accountId}/companies`, { company }))
    .payload
