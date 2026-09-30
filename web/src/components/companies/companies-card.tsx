// Port de components-next/Companies/CompaniesCard/CompaniesCard.vue; ícones equivalentes em Phosphor.
import { useTranslation } from 'react-i18next'

import type { Company } from '../../api/companies'
import { exactTimestamp, longTimeAgo } from '../../shared/time-ago'
import { Avatar } from '../next/avatar'
import { CardLayout } from '../next/card-layout'
import { Icon } from '../next/icon'

export function CompaniesCard({
  company,
  onShowCompany,
}: {
  company: Company
  onShowCompany: (id: number) => void
}) {
  const { t } = useTranslation()
  return (
    <CardLayout layout="row">
      <button
        type="button"
        onClick={() => onShowCompany(company.id)}
        className="flex w-full cursor-pointer items-center gap-4 text-start"
      >
        <Avatar
          name={company.name || t('COMPANIES.UNNAMED')}
          src={company.avatar_url}
          size={42}
          className="shrink-0"
        />
        <div className="flex min-w-0 flex-1 flex-col gap-0.5">
          <div className="flex min-w-0 flex-wrap items-center gap-x-4 gap-y-1">
            <span className="truncate text-base font-medium text-n-slate-12">
              {company.name || t('COMPANIES.UNNAMED')}
            </span>
            {!!company.contacts_count && (
              <span className="inline-flex items-center gap-1.5 truncate text-sm text-n-slate-11">
                <Icon name="ph-address-book" className="size-3.5" />
                {t('COMPANIES.CONTACTS_COUNT', {
                  n: company.contacts_count,
                  count: company.contacts_count,
                })}
              </span>
            )}
          </div>
          <div className="flex items-center justify-between gap-3">
            <div className="flex min-w-0 items-center">
              {company.domain && (
                <span
                  onClick={(e) => e.stopPropagation()}
                  className="inline-flex cursor-text items-center gap-1.5 truncate text-sm text-n-slate-11"
                >
                  <Icon name="ph-globe" className="size-3.5" />
                  <span className="truncate">{company.domain}</span>
                </span>
              )}
            </div>
            {company.last_activity_at && (
              <span
                title={exactTimestamp(company.last_activity_at)}
                className="inline-flex shrink-0 items-center gap-1.5 text-sm text-n-slate-11"
              >
                {longTimeAgo(company.last_activity_at)}
              </span>
            )}
          </div>
        </div>
      </button>
    </CardLayout>
  )
}
