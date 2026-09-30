import { createFileRoute } from '@tanstack/react-router'
import { useCallback } from 'react'

import { CompaniesIndex } from '../../../../components/companies/companies-index'
import { companySort } from '../../../../components/companies/company-sort'
import type { CompanySearch } from '../../../../api/companies'

export const Route = createFileRoute('/app/_authenticated/companies/')({
  validateSearch: (
    raw: Record<string, unknown>,
  ): { page?: number; search?: string; sort?: string } => {
    const page = Number(raw.page)
    return {
      ...(Number.isInteger(page) && page > 1 ? { page } : {}),
      ...(typeof raw.search === 'string' && raw.search ? { search: raw.search } : {}),
      ...(typeof raw.sort === 'string' ? { sort: companySort(raw.sort) } : {}),
    }
  },
  component: CompaniesPage,
})
function CompaniesPage() {
  const { page = 1, search = '', sort } = Route.useSearch()
  const navigate = Route.useNavigate()
  const onNavigate = useCallback(
    (next: CompanySearch) =>
      void navigate({
        search: { page: next.page, search: next.search || undefined, sort: next.sort },
        replace: true,
      }),
    [navigate],
  )
  return (
    <CompaniesIndex
      page={page}
      search={search}
      sort={sort}
      onNavigate={onNavigate}
      onShowCompany={(id) =>
        void navigate({ to: '/app/companies/$companyId', params: { companyId: String(id) } })
      }
    />
  )
}
