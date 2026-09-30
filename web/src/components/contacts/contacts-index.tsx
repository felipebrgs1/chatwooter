// Port de routes/dashboard/contacts/pages/ContactsIndex.vue: lista paginada ou busca, ordenação em ui_settings.
// Fora desta fatia: segmentos, filtros avançados, visão por etiqueta, "active" e ações em massa.
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { profileQuery, updateUiSettings } from '../../api/auth'
import {
  CONTACTS_PER_PAGE,
  contactKeys,
  contactsQuery,
  updateContact,
  deleteContact,
  type ContactUpdate,
} from '../../api/contacts'
import { ApiError } from '../../api/client'
import { showAlert } from '../toast/alert'
import { api } from '../../api/client'
import type { ContactsPage, Profile } from '../../api/types'
import { useAccountId } from '../../api/use-account-id'
import { Button } from '../next/button'
import { Spinner } from '../next/spinner'
import { ContactEmptyState } from './contact-empty-state'
import { ContactHeader } from './contact-header'
import { CONTACT_SORTS, type ContactOrdering, type ContactSort } from './contact-sort'
import { ContactsCard } from './contacts-card'
import { ContactsListLayout } from './contacts-list-layout'

// Única ordem coberta por índice (index_contacts_on_account_id_and_last_activity_at)
const DEFAULT_SORT = '-last_activity_at'
const DEBOUNCE_DELAY = 300

type Props = {
  page: number
  search: string
  onNavigate: (next: { page: number; search: string }) => void
  onShowContact: (id: number) => void
}

function parseSort(value: unknown): { sort: ContactSort; order: ContactOrdering } {
  const raw = typeof value === 'string' && value ? value : DEFAULT_SORT
  const order = raw.startsWith('-') ? '-' : ''
  const sort = raw.replace(/^-/, '') as ContactSort
  return CONTACT_SORTS.includes(sort) ? { sort, order } : parseSort(DEFAULT_SORT)
}

export function ContactsIndex({ page, search, onNavigate, onShowContact }: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const queryClient = useQueryClient()
  const { data: profile } = useQuery(profileQuery)
  const { sort, order } = parseSort(profile?.ui_settings.contacts_sort_by)
  const sortAttr = `${order}${sort}`

  const [expandedCardId, setExpandedCardId] = useState<number | null>(null)
  const isAdmin =
    profile?.accounts.find((account) => account.id === accountId)?.role === 'administrator'
  const update = useMutation({
    mutationFn: ({ id, data }: { id: number; data: ContactUpdate }) =>
      updateContact(accountId, id, data),
    onSuccess: (saved) => {
      queryClient.setQueryData(contactKeys.detail(accountId, saved.id), saved)
      void queryClient.invalidateQueries({ queryKey: contactKeys.all(accountId) })
      showAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE'))
    },
    onError: (error) => {
      const message = error instanceof ApiError ? error.messages.join(' ') : ''
      const prefix = 'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM'
      showAlert(
        t(
          /email/i.test(message)
            ? `${prefix}.FORM.EMAIL_ADDRESS.DUPLICATE`
            : /phone/i.test(message)
              ? `${prefix}.FORM.PHONE_NUMBER.DUPLICATE`
              : `${prefix}.ERROR_MESSAGE`,
        ),
      )
    },
  })
  const remove = useMutation({
    mutationFn: (id: number) => deleteContact(accountId, id),
    onSuccess: (_, id) => {
      queryClient.removeQueries({ queryKey: contactKeys.detail(accountId, id) })
      void queryClient.invalidateQueries({ queryKey: contactKeys.all(accountId) })
      setExpandedCardId(null)
      showAlert(t('CONTACTS_LAYOUT.DETAILS.DELETE_DIALOG.API.SUCCESS_MESSAGE'))
    },
    onError: () => showAlert(t('CONTACTS_LAYOUT.DETAILS.DELETE_DIALOG.API.ERROR_MESSAGE')),
  })

  // o campo muda na hora; a URL (e a busca) só depois da pausa de digitação
  const [searchValue, setSearchValue] = useState(search)
  // a URL mudou por fora (voltar, sidebar): o campo acompanha
  const [urlSearch, setUrlSearch] = useState(search)
  if (urlSearch !== search) {
    setUrlSearch(search)
    setSearchValue(search)
  }
  useEffect(() => {
    if (searchValue === search) return
    const timer = setTimeout(() => onNavigate({ page: 1, search: searchValue }), DEBOUNCE_DELAY)
    return () => clearTimeout(timer)
  }, [searchValue, search, onNavigate])

  const list = useQuery({ ...contactsQuery(accountId, { page, sort: sortAttr }), enabled: !search })
  // a busca rola com "Load more" (has_more), acumulando as páginas
  const found = useInfiniteQuery({
    queryKey: [...contactKeys.all(accountId), 'search', search, sortAttr],
    queryFn: ({ pageParam }) =>
      api.get<ContactsPage>(
        `/api/v1/accounts/${accountId}/contacts/search?${new URLSearchParams({
          include_contact_inboxes: 'false',
          page: String(pageParam),
          sort: sortAttr,
          q: search,
        })}`,
      ),
    initialPageParam: 1,
    getNextPageParam: (last, all) => (last.meta.has_more ? all.length + 1 : undefined),
    enabled: Boolean(search),
  })

  const isSearchView = Boolean(search)
  const contacts = isSearchView
    ? (found.data?.pages.flatMap((p) => p.payload) ?? [])
    : (list.data?.payload ?? [])
  const isFetchingList = isSearchView ? found.isPending : list.isPending
  const hasContacts = contacts.length > 0
  const totalItems = list.data?.meta.count ?? 0
  const currentPage = Number(list.data?.meta.current_page ?? page)

  const showEmptyStateLayout = !isSearchView && !hasContacts && page === 1
  const headerTitle = isSearchView
    ? t('CONTACTS_LAYOUT.HEADER.SEARCH_TITLE')
    : t('CONTACTS_LAYOUT.HEADER.TITLE')
  const emptyMessage = isSearchView
    ? t('CONTACTS_LAYOUT.EMPTY_STATE.SEARCH_EMPTY_STATE_TITLE')
    : t('CONTACTS_LAYOUT.EMPTY_STATE.LIST_EMPTY_STATE_TITLE')

  async function handleSort(next: { sort: ContactSort; order: ContactOrdering }) {
    const previous = queryClient.getQueryData<Profile>(profileQuery.queryKey)
    const merged = { ...previous?.ui_settings, contacts_sort_by: `${next.order}${next.sort}` }
    queryClient.setQueryData<Profile>(
      profileQuery.queryKey,
      (p) => p && { ...p, ui_settings: merged },
    )
    try {
      const saved = await updateUiSettings(merged)
      if (saved) queryClient.setQueryData(profileQuery.queryKey, saved)
    } catch {
      queryClient.setQueryData(profileQuery.queryKey, previous)
    }
  }

  return (
    <div className="m-0 flex h-full flex-1 flex-col justify-between overflow-auto bg-n-surface-1">
      <ContactsListLayout
        header={
          <ContactHeader
            headerTitle={headerTitle}
            searchValue={searchValue}
            activeSort={sort}
            activeOrdering={order}
            onSearch={setSearchValue}
            onSortChange={(next) => void handleSort(next)}
          />
        }
        showPagination={!isFetchingList && hasContacts && !isSearchView}
        currentPage={currentPage}
        totalItems={totalItems}
        itemsPerPage={CONTACTS_PER_PAGE}
        onPageChange={(next) => onNavigate({ page: next, search })}
      >
        {isFetchingList ? (
          <div className="flex items-center justify-center py-10 text-n-slate-11">
            <Spinner />
          </div>
        ) : showEmptyStateLayout ? (
          <ContactEmptyState
            className="pt-14"
            title={t('CONTACTS_LAYOUT.EMPTY_STATE.TITLE')}
            subtitle={t('CONTACTS_LAYOUT.EMPTY_STATE.SUBTITLE')}
            buttonLabel={t('CONTACTS_LAYOUT.EMPTY_STATE.BUTTON_LABEL')}
          />
        ) : !hasContacts ? (
          <div className="flex items-center justify-center py-10">
            <span className="text-base text-n-slate-11">{emptyMessage}</span>
          </div>
        ) : (
          <div className="flex flex-col gap-4 pb-6 pt-4">
            <div className="flex flex-col gap-4">
              {contacts.map((contact) => (
                <div key={contact.id} className="relative">
                  <ContactsCard
                    contact={contact}
                    onShowContact={onShowContact}
                    isExpanded={expandedCardId === contact.id}
                    isUpdating={update.isPending}
                    isAdmin={isAdmin}
                    onToggle={() =>
                      setExpandedCardId(expandedCardId === contact.id ? null : contact.id)
                    }
                    onUpdate={(data) => update.mutate({ id: contact.id, data })}
                    onDelete={() => remove.mutate(contact.id)}
                  />
                </div>
              ))}
            </div>
          </div>
        )}
        {/* ContactsLoadMore.vue */}
        {isSearchView && found.hasNextPage && (
          <div className="flex justify-center py-4">
            <Button
              label={t('CONTACTS_LAYOUT.LOAD_MORE')}
              isLoading={found.isFetchingNextPage}
              variant="faded"
              color="slate"
              size="sm"
              onClick={() => void found.fetchNextPage()}
            />
          </div>
        )}
      </ContactsListLayout>
    </div>
  )
}
