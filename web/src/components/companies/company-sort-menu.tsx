// Port de components-next/Companies/CompaniesHeader/components/CompanySortMenu.vue.
import { useTranslation } from 'react-i18next'

import { Button } from '../next/button'
import { cx } from '../next/cx'
import { DropdownContainer } from '../next/dropdown-container'
import { SelectMenu } from '../next/select-menu'

import { COMPANY_SORTS } from './company-sort'
export function CompanySortMenu({
  value,
  onChange,
}: {
  value: string
  onChange: (value: string) => void
}) {
  const { t } = useTranslation()
  const sort = value.replace(/^-/, '')
  const order = value.startsWith('-') ? 'desc' : 'asc'
  const sortLabel = t('COMPANIES.SORT_BY.LABEL')
  const orderLabel = t('COMPANIES.ORDER.LABEL')
  return (
    <DropdownContainer
      trigger={({ open, toggle, triggerProps }) => (
        <Button
          {...triggerProps}
          aria-label={sortLabel}
          icon="ph-arrows-down-up"
          color="slate"
          size="sm"
          variant="ghost"
          className={cx(open && 'bg-n-alpha-2')}
          onClick={toggle}
        />
      )}
    >
      <div className="absolute top-full z-50 mt-1 flex w-72 flex-col gap-4 rounded-xl border border-n-weak bg-n-alpha-3 p-4 backdrop-blur-[100px] ltr:-right-32 rtl:-left-32 sm:ltr:right-0 sm:rtl:left-0">
        <div className="flex items-center justify-between gap-2">
          <span className="text-sm text-n-slate-12">{sortLabel}</span>
          <SelectMenu
            label={sortLabel}
            value={sort}
            options={COMPANY_SORTS.map((value) => ({
              value,
              label: t(`COMPANIES.SORT_BY.OPTIONS.${value.toUpperCase()}`),
            }))}
            onChange={(next) => onChange(`${order === 'desc' ? '-' : ''}${next}`)}
          />
        </div>
        <div className="flex items-center justify-between gap-2">
          <span className="text-sm text-n-slate-12">{orderLabel}</span>
          <SelectMenu
            label={orderLabel}
            value={order}
            options={[
              { value: 'asc', label: t('COMPANIES.ORDER.OPTIONS.ASCENDING') },
              { value: 'desc', label: t('COMPANIES.ORDER.OPTIONS.DESCENDING') },
            ]}
            onChange={(next) => onChange(`${next === 'desc' ? '-' : ''}${sort}`)}
          />
        </div>
      </div>
    </DropdownContainer>
  )
}
