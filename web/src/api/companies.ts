import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { ContactListItem, ContactNote, Conversation } from './types'

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

export const updateCompany = async (accountId: number, id: number, company: CompanyInput) =>
  (
    await api.put<{ payload: Company }>(`/api/v1/accounts/${accountId}/companies/${id}`, {
      company,
    })
  ).payload

export const deleteCompany = (accountId: number, id: number) =>
  api.delete(`/api/v1/accounts/${accountId}/companies/${id}`)

export type CompanyContact = ContactListItem & {
  company_id: number | null
  linked_to_current_company: boolean
  company: Company | null
}
export type CompanyContactsPage = {
  meta: { total_count: number; page: number | string }
  payload: CompanyContact[]
}
const companyPath = (accountId: number, id: number) =>
  `/api/v1/accounts/${accountId}/companies/${id}`
export const companyContactsQuery = (accountId: number, id: number, page = 1) =>
  queryOptions({
    queryKey: [...companyKeys.all(accountId), 'detail', id, 'contacts', page],
    queryFn: () =>
      api.get<CompanyContactsPage>(`${companyPath(accountId, id)}/contacts?page=${page}`),
  })
export const companyContactSearchQuery = (accountId: number, id: number, search: string) =>
  queryOptions({
    queryKey: [...companyKeys.all(accountId), 'detail', id, 'contact-search', search],
    queryFn: () =>
      api.get<CompanyContactsPage>(
        `${companyPath(accountId, id)}/contacts/search?${new URLSearchParams({ q: search, page: '1' })}`,
      ),
  })
export const linkCompanyContact = (accountId: number, id: number, contactId: number) =>
  api.post<{ payload: CompanyContact }>(`${companyPath(accountId, id)}/contacts`, {
    contact_id: contactId,
  })
export const unlinkCompanyContact = (accountId: number, id: number, contactId: number) =>
  api.delete(`${companyPath(accountId, id)}/contacts/${contactId}`)
export const companyConversationsQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: [...companyKeys.all(accountId), 'detail', id, 'conversations'],
    queryFn: () =>
      api
        .get<{ payload: Conversation[] }>(`${companyPath(accountId, id)}/conversations`)
        .then((r) => r.payload),
  })
export type CompanyNote = ContactNote & { contact: ContactListItem }
export const companyNotesQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: [...companyKeys.all(accountId), 'detail', id, 'notes'],
    queryFn: () =>
      api
        .get<{ payload: CompanyNote[] }>(`${companyPath(accountId, id)}/notes`)
        .then((r) => r.payload),
  })
export async function uploadCompanyAvatar(accountId: number, id: number, file: File) {
  const data = new FormData()
  data.append('company[avatar]', file, file.name)
  const response = await fetch(companyPath(accountId, id), {
    method: 'PUT',
    credentials: 'same-origin',
    body: data,
  })
  if (!response.ok) throw new Error('Avatar upload failed')
  return ((await response.json()) as { payload: Company }).payload
}
export const deleteCompanyAvatar = (accountId: number, id: number) =>
  api.delete(`${companyPath(accountId, id)}/avatar`)
