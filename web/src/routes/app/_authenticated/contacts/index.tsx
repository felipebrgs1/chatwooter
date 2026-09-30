import { createFileRoute } from '@tanstack/react-router'
import { useCallback } from 'react'

import { ContactsIndex } from '../../../../components/contacts/contacts-index'

type ContactsSearch = { page?: number; search?: string }

// /app/contacts?page=2&search=ana (no Chatwoot: /app/accounts/:id/contacts com os mesmos query params)
export const Route = createFileRoute('/app/_authenticated/contacts/')({
  validateSearch: (raw: Record<string, unknown>): ContactsSearch => {
    const page = Number(raw.page)
    const search =
      typeof raw.search === 'string' || typeof raw.search === 'number' ? String(raw.search) : ''
    return {
      ...(Number.isInteger(page) && page > 1 ? { page } : {}),
      ...(search ? { search } : {}),
    }
  },
  component: ContactsPage,
})

function ContactsPage() {
  const { page = 1, search = '' } = Route.useSearch()
  const navigate = Route.useNavigate()

  const onNavigate = useCallback(
    (next: { page: number; search: string }) =>
      void navigate({
        search: {
          ...(next.page > 1 ? { page: next.page } : {}),
          ...(next.search ? { search: next.search } : {}),
        },
        replace: true,
      }),
    [navigate],
  )

  return (
    <ContactsIndex
      page={page}
      search={search}
      onNavigate={onNavigate}
      onShowContact={(id) =>
        void navigate({ to: '/app/contacts/$contactId', params: { contactId: String(id) } })
      }
    />
  )
}
