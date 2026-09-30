// Contatos: api/v1/accounts/contacts_controller.rb (index, search, show), nos parâmetros de dashboard/api/contacts.js.
import { keepPreviousData, queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { ContactListItem, ContactNote, ContactsPage, Conversation } from './types'

/** Itens por página do ContactsController (RESULTS_PER_PAGE). */
export const CONTACTS_PER_PAGE = 15

export type ContactsParams = { page: number; sort: string; search?: string; label?: string }

export const contactKeys = {
  all: (accountId: number) => ['accounts', accountId, 'contacts'] as const,
  list: (accountId: number, params: ContactsParams) =>
    [...contactKeys.all(accountId), 'list', params] as const,
  detail: (accountId: number, id: number) => [...contactKeys.all(accountId), 'detail', id] as const,
}

// buildContactParams: include_contact_inboxes=false, page, sort, q e labels[]
function query({ page, sort, search, label }: ContactsParams) {
  const params = new URLSearchParams({ include_contact_inboxes: 'false', page: String(page), sort })
  if (search) params.set('q', search)
  if (label) params.append('labels[]', label)
  return params.toString()
}

export const contactsQuery = (accountId: number, params: ContactsParams) =>
  queryOptions({
    queryKey: contactKeys.list(accountId, params),
    queryFn: () =>
      api.get<ContactsPage>(
        `/api/v1/accounts/${accountId}/contacts${params.search ? '/search' : ''}?${query(params)}`,
      ),
    // trocar de página ou de ordenação mantém a lista anterior na tela até a nova chegar
    placeholderData: keepPreviousData,
  })

export const contactQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: contactKeys.detail(accountId, id),
    queryFn: () =>
      api
        .get<{ payload: ContactListItem }>(`/api/v1/accounts/${accountId}/contacts/${id}`)
        .then((r) => r.payload),
  })

// ---- Detalhe: contacts_controller#update/#destroy e os controllers aninhados em contacts/ ----

export type ContactUpdate = Partial<{
  name: string
  email: string
  phone_number: string
  identifier: string
  blocked: boolean
  additional_attributes: Record<string, unknown>
  custom_attributes: Record<string, unknown>
}>

const contactPath = (accountId: number, id: number) =>
  `/api/v1/accounts/${accountId}/contacts/${id}`

export const updateContact = (accountId: number, id: number, data: ContactUpdate) =>
  api.put<{ payload: ContactListItem }>(contactPath(accountId, id), data).then((r) => r.payload)

export const deleteContact = (accountId: number, id: number) =>
  api.delete<unknown>(contactPath(accountId, id))

export const contactLabelsQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: [...contactKeys.detail(accountId, id), 'labels'],
    queryFn: () =>
      api.get<{ payload: string[] }>(`${contactPath(accountId, id)}/labels`).then((r) => r.payload),
  })

export const updateContactLabels = (accountId: number, id: number, labels: string[]) =>
  api
    .post<{ payload: string[] }>(`${contactPath(accountId, id)}/labels`, { labels })
    .then((r) => r.payload)

export const contactConversationsQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: [...contactKeys.detail(accountId, id), 'conversations'],
    queryFn: () =>
      api
        .get<{ payload: Conversation[] }>(`${contactPath(accountId, id)}/conversations`)
        .then((r) => r.payload),
  })

export const contactNotesQuery = (accountId: number, id: number) =>
  queryOptions({
    queryKey: [...contactKeys.detail(accountId, id), 'notes'],
    queryFn: () => api.get<ContactNote[]>(`${contactPath(accountId, id)}/notes`),
  })

export const createContactNote = (accountId: number, id: number, content: string) =>
  api.post<ContactNote>(`${contactPath(accountId, id)}/notes`, { content })

export const deleteContactNote = (accountId: number, id: number, noteId: number) =>
  api.delete<unknown>(`${contactPath(accountId, id)}/notes/${noteId}`)
