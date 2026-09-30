// Port de routes/dashboard/companies/pages/CompaniesIndex.vue e CompaniesListLayout.vue.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { profileQuery, updateUiSettings } from '../../api/auth'
import {
  companiesQuery,
  companyKeys,
  companyQuery,
  createCompany,
  type CompanySearch,
} from '../../api/companies'
import type { Profile } from '../../api/types'
import { useAccountId } from '../../api/use-account-id'
import { Button } from '../next/button'
import { DropdownContainer } from '../next/dropdown-container'
import { Icon } from '../next/icon'
import { Input } from '../next/input'
import { PaginationFooter } from '../next/pagination-footer'
import { CompaniesCard } from './companies-card'
import { CompanyCreateDialog } from './company-create-dialog'
import { CompanySortMenu } from './company-sort-menu'
import { companySort } from './company-sort'

type Props = {
  page: number
  search: string
  sort?: string
  onNavigate: (next: CompanySearch) => void
  onShowCompany: (id: number) => void
}
export function CompaniesIndex({
  page,
  search,
  sort: routeSort,
  onNavigate,
  onShowCompany,
}: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const client = useQueryClient()
  const { data: profile } = useQuery(profileQuery)
  const sort = companySort(routeSort ?? profile?.ui_settings.companies_sort_by)
  const query = useQuery(companiesQuery(accountId, { page, search, sort }))
  const [searchValue, setSearchValue] = useState(search)
  const [previousSearch, setPreviousSearch] = useState(search)
  if (previousSearch !== search) {
    setPreviousSearch(search)
    setSearchValue(search)
  }
  const [creating, setCreating] = useState(false)
  const create = useMutation({
    mutationFn: (input: Parameters<typeof createCompany>[1]) => createCompany(accountId, input),
    onSuccess: (company) => {
      client.setQueryData(companyQuery(accountId, company.id).queryKey, company)
      void client.invalidateQueries({ queryKey: companyKeys.all(accountId) })
      setCreating(false)
      onShowCompany(company.id)
    },
  })
  useEffect(() => {
    if (searchValue === search) return
    const timer = setTimeout(() => onNavigate({ page: 1, search: searchValue, sort }), 300)
    return () => clearTimeout(timer)
  }, [searchValue, search, sort, onNavigate])
  async function handleSort(next: string) {
    const previous = client.getQueryData<Profile>(profileQuery.queryKey)
    const settings = { ...previous?.ui_settings, companies_sort_by: next }
    client.setQueryData<Profile>(profileQuery.queryKey, (p) => p && { ...p, ui_settings: settings })
    onNavigate({ page: 1, search, sort: next })
    try {
      const saved = await updateUiSettings(settings)
      client.setQueryData(profileQuery.queryKey, saved)
    } catch {
      client.setQueryData(profileQuery.queryKey, previous)
    }
  }
  return (
    <section className="flex h-full w-full justify-evenly gap-4 overflow-hidden bg-n-surface-1">
      <div className="flex h-full w-full flex-col transition-all duration-300">
        <header className="sticky top-0 z-10 px-6">
          <div className="mx-auto flex w-full max-w-5xl items-start justify-between gap-2 py-6 sm:items-center">
            <h1 className="truncate text-xl font-medium text-n-slate-12">
              {t('COMPANIES.HEADER')}
            </h1>
            <div className="flex shrink-0 flex-col items-center gap-4 sm:flex-row">
              <Input
                type="search"
                value={searchValue}
                aria-label={t('COMPANIES.SEARCH_PLACEHOLDER')}
                placeholder={t('COMPANIES.SEARCH_PLACEHOLDER')}
                onChange={(e) => setSearchValue(e.target.value)}
                size="sm"
                inputClassName="h-8 bg-n-alpha-2 !py-1 ltr:!pl-8 rtl:!pr-8"
                prefix={
                  <Icon
                    name="ph-magnifying-glass"
                    className="absolute top-1/2 size-4 -translate-y-1/2 text-n-slate-11 ltr:left-2 rtl:right-2"
                  />
                }
              />
              <div className="flex shrink-0 items-center gap-2">
                <CompanySortMenu value={sort} onChange={(next) => void handleSort(next)} />
                {/* CompanyMoreActions.vue */}
                <DropdownContainer
                  trigger={({ toggle, triggerProps }) => (
                    <Button
                      {...triggerProps}
                      aria-label={t('CONVERSATION.HEADER.MORE_ACTIONS')}
                      icon="ph-dots-three-vertical"
                      color="slate"
                      variant="ghost"
                      size="sm"
                      onClick={toggle}
                    />
                  )}
                >
                  {({ close }) => (
                    <div className="absolute top-full z-50 mt-1 w-52 rounded-xl bg-n-alpha-3 p-2 shadow-lg outline outline-1 outline-n-container backdrop-blur-[100px] ltr:right-0 rtl:left-0">
                      <Button
                        label={t('COMPANIES.ACTIONS.CREATE')}
                        icon="ph-plus"
                        color="slate"
                        variant="ghost"
                        size="sm"
                        className="w-full justify-start"
                        onClick={() => {
                          close()
                          create.reset()
                          setCreating(true)
                        }}
                      />
                    </div>
                  )}
                </DropdownContainer>
              </div>
            </div>
          </div>
        </header>
        <main className="flex-1 overflow-y-auto px-6">
          <div className="mx-auto w-full max-w-5xl py-4">
            {query.isPending ? (
              <div className="flex items-center justify-center p-8 text-base text-n-slate-11">
                {t('COMPANIES.LOADING')}
              </div>
            ) : // O original trata falha como lista vazia; mostramos o erro genérico para não afirmar ausência de dados.
            query.isError ? (
              <p role="alert" className="p-8 text-center text-n-ruby-11">
                {t('ONBOARDING_INBOX_SETUP.ERROR')}
              </p>
            ) : !query.data.payload.length ? (
              <div className="flex items-center justify-center p-8 text-base text-n-slate-11">
                {t('COMPANIES.EMPTY_STATE.TITLE')}
              </div>
            ) : (
              <div className="flex flex-col gap-4">
                {query.data.payload.map((company) => (
                  <CompaniesCard key={company.id} company={company} onShowCompany={onShowCompany} />
                ))}
              </div>
            )}
          </div>
        </main>
        {!!query.data?.payload.length && (
          <footer className="sticky bottom-0 z-0">
            <PaginationFooter
              currentPage={page}
              totalItems={query.data.meta.total_count}
              itemsPerPage={25}
              currentPageInfo="COMPANIES_LAYOUT.PAGINATION_FOOTER.SHOWING"
              className="max-w-[67rem]"
              onPageChange={(page) => onNavigate({ page, search, sort })}
            />
          </footer>
        )}
        {creating && (
          <CompanyCreateDialog
            isLoading={create.isPending}
            error={create.isError ? t('COMPANIES.CREATE.MESSAGES.ERROR') : undefined}
            onClose={() => setCreating(false)}
            onCreate={(input) => create.mutate(input)}
          />
        )}
      </div>
    </section>
  )
}
