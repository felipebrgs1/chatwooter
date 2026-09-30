// Port de components-next/Contacts/ContactsHeader/components/ContactSortMenu.vue.
import { useTranslation } from 'react-i18next'

import { Button } from '../next/button'
import { cx } from '../next/cx'
import { DropdownContainer } from '../next/dropdown-container'
import { SelectMenu } from '../next/select-menu'
import { CONTACT_SORTS, type ContactOrdering, type ContactSort } from './contact-sort'

const sortKeys: Record<ContactSort, string> = {
  name: 'NAME',
  email: 'EMAIL',
  company_name: 'COMPANY',
  country: 'COUNTRY',
  city: 'CITY',
  last_activity_at: 'LAST_ACTIVITY',
  created_at: 'CREATED_AT',
}

type Props = {
  activeSort: ContactSort
  activeOrdering: ContactOrdering
  onSortChange: (sort: { sort: ContactSort; order: ContactOrdering }) => void
}

export function ContactSortMenu({ activeSort, activeOrdering, onSortChange }: Props) {
  const { t } = useTranslation()
  const sortOptions = CONTACT_SORTS.map((value) => ({
    value,
    label: t(`CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.${sortKeys[value]}`),
  }))
  const orderOptions = [
    { value: 'asc', label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.OPTIONS.ASCENDING') },
    { value: 'desc', label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.OPTIONS.DESCENDING') },
  ] as const
  const sortLabel = t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.LABEL')
  const orderLabel = t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.LABEL')

  return (
    <DropdownContainer
      trigger={({ open, toggle, triggerProps }) => (
        <Button
          {...triggerProps}
          icon="ph-arrows-down-up"
          color="slate"
          size="sm"
          variant="ghost"
          aria-label={sortLabel}
          className={cx(triggerProps.className, open && 'bg-n-alpha-2')}
          onClick={toggle}
        />
      )}
    >
      <div className="absolute top-full z-50 mt-1 flex w-72 flex-col gap-4 rounded-xl border border-n-weak bg-n-alpha-3 p-4 backdrop-blur-[100px] ltr:-right-32 rtl:-left-32 sm:ltr:right-0 sm:rtl:left-0">
        <div className="flex items-center justify-between gap-2">
          <span className="text-sm text-n-slate-12">{sortLabel}</span>
          <SelectMenu
            label={sortLabel}
            value={activeSort}
            options={sortOptions}
            onChange={(sort) => onSortChange({ sort, order: activeOrdering })}
          />
        </div>
        <div className="flex items-center justify-between gap-2">
          <span className="text-sm text-n-slate-12">{orderLabel}</span>
          {/* o valor da ordem é '' ou '-' (prefixo do Sift); o SelectMenu precisa de valores não vazios */}
          <SelectMenu
            label={orderLabel}
            value={activeOrdering === '-' ? 'desc' : 'asc'}
            options={[...orderOptions]}
            onChange={(order) =>
              onSortChange({ sort: activeSort, order: order === 'desc' ? '-' : '' })
            }
          />
        </div>
      </div>
    </DropdownContainer>
  )
}
