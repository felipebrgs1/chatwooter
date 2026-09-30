// Port de components-next/Companies/CompanySelector.vue.
import { useCallback, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { companiesQuery, createCompany, companyKeys, type CompanyInput } from '../../api/companies'
import { useAccountId } from '../../api/use-account-id'
import { Combobox } from '../next/combobox'
import { CompanyCreateDialog } from './company-create-dialog'
import { showAlert } from '../toast/alert'
export function CompanySelector({
  value,
  selectedName,
  onSelect,
  isDetailsView = false,
}: {
  value: number | null
  selectedName: string
  isDetailsView?: boolean
  onSelect: (value: { id: number | null; name: string }) => void
}) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const client = useQueryClient()
  const [opened, setOpened] = useState(false)
  const [search, setSearch] = useState('')
  const [createName, setCreateName] = useState<string | null>(null)
  const query = useQuery({
    ...companiesQuery(accountId, { page: 1, search, sort: 'name' }),
    enabled: opened,
  })
  const create = useMutation({
    mutationFn: (data: CompanyInput) => createCompany(accountId, data),
    onSuccess: (company) => {
      void client.invalidateQueries({ queryKey: companyKeys.all(accountId) })
      setCreateName(null)
      onSelect({ id: company.id, name: company.name })
      showAlert(t('COMPANIES.CREATE.MESSAGES.SUCCESS'))
    },
  })
  const onSearch = useCallback((value: string) => setSearch(value.trim()), [])
  const options = (query.data?.payload ?? []).map((company) => ({
    value: company.id,
    label: company.name,
  }))
  if (value && selectedName && !options.some((option) => option.value === value))
    options.unshift({ value, label: selectedName })
  const allOptions: Array<{ value: string | number; label: string }> = [...options]
  if (search && !options.some((option) => option.label.toLowerCase() === search.toLowerCase()))
    allOptions.push({
      value: `create:${search}`,
      label: t('COMPANIES.SELECTOR.CREATE_OPTION', { name: search }),
    })
  return (
    <>
      <Combobox
        id="contact-company-selector"
        value={value}
        displayLabel={selectedName}
        options={allOptions}
        useApiResults
        placeholder={t('COMPANIES.SELECTOR.PLACEHOLDER')}
        searchPlaceholder={t('COMPANIES.SEARCH_PLACEHOLDER')}
        emptyState={t('COMBOBOX.EMPTY_STATE')}
        onOpen={() => {
          setOpened(true)
          setSearch('')
        }}
        onSearch={onSearch}
        className={
          isDetailsView
            ? '[&>button]:!bg-n-alpha-black2'
            : '[&>button:not(:focus)]:!outline-transparent'
        }
        onChange={(selected) => {
          if (typeof selected === 'string' && selected.startsWith('create:')) {
            setCreateName(selected.slice(7))
            setSearch('')
            create.reset()
            return
          }
          const id = Number(selected)
          onSelect({
            id: id === value ? null : id,
            name: id === value ? '' : (options.find((option) => option.value === id)?.label ?? ''),
          })
        }}
      />
      {createName !== null && (
        <CompanyCreateDialog
          initialName={createName}
          isLoading={create.isPending}
          error={create.isError ? t('COMPANIES.CREATE.MESSAGES.ERROR') : undefined}
          onClose={() => setCreateName(null)}
          onCreate={(data) => create.mutate(data)}
        />
      )}
    </>
  )
}
