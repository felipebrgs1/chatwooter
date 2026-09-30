// Port inicial de CompaniesDetailsLayout.vue e CompanyDetail/CompanyProfileCard.vue.
// Edição, avatar, contatos, notas, histórico e exclusão entram nas próximas fatias; controles sem backend ficam desabilitados.
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { companyQuery } from '../../api/companies'
import { ApiError } from '../../api/client'
import { useAccountId } from '../../api/use-account-id'
import { exactTimestamp, longTimeAgo } from '../../shared/time-ago'
import { Avatar } from '../next/avatar'
import { Button } from '../next/button'
import { Input } from '../next/input'

export function CompanyDetail({ companyId, onBack }: { companyId: number; onBack: () => void }) {
  const { t } = useTranslation()
  const query = useQuery(companyQuery(useAccountId(), companyId))
  const company = query.data
  return (
    <section className="flex h-full w-full justify-evenly overflow-hidden bg-n-surface-1">
      <div className="flex h-full w-full flex-col transition-all duration-300 ltr:2xl:ml-56 rtl:2xl:mr-56">
        <header className="sticky top-0 z-10 px-6">
          <div className="mx-auto flex w-full max-w-[40.625rem] items-center gap-2 py-7">
            <Button label={t('COMPANIES.HEADER')} variant="link" color="slate" onClick={onBack} />
            {company && <span className="text-sm text-n-slate-12">/ {company.name}</span>}
          </div>
        </header>
        <main className="flex-1 overflow-y-auto px-6">
          <div className="mx-auto w-full max-w-[40.625rem] py-4">
            {query.isPending ? (
              <span className="text-sm text-n-slate-11">{t('COMPANIES.DETAIL.LOADING')}</span>
            ) : query.isError &&
              !(query.error instanceof ApiError && query.error.status === 404) ? (
              <p role="alert" className="text-center text-n-ruby-11">
                {t('ONBOARDING_INBOX_SETUP.ERROR')}
              </p>
            ) : query.isError ? (
              <div className="text-center">
                <h2 className="text-base text-n-slate-12">
                  {t('COMPANIES.DETAIL.EMPTY_STATE.TITLE')}
                </h2>
                <p className="text-sm text-n-slate-11">
                  {t('COMPANIES.DETAIL.EMPTY_STATE.SUBTITLE')}
                </p>
              </div>
            ) : (
              company && (
                <div className="flex flex-col items-start gap-8 pb-6">
                  <div className="flex flex-col items-start gap-3">
                    <Avatar name={company.name} size={72} />
                    <div className="flex flex-col gap-1">
                      <h3 className="text-base font-medium text-n-slate-12">{company.name}</h3>
                      <span
                        className="text-sm leading-6 text-n-slate-11"
                        title={exactTimestamp(company.created_at)}
                      >
                        {t('COMPANIES.DETAIL.PROFILE.CREATED_AT', {
                          date: longTimeAgo(company.created_at),
                        })}
                      </span>
                    </div>
                  </div>
                  <div className="flex w-full flex-col items-start gap-6">
                    <span className="py-1 text-sm font-medium text-n-slate-12">
                      {t('COMPANIES.DETAIL.PROFILE.TITLE')}
                    </span>
                    <div className="grid w-full gap-4 sm:grid-cols-2">
                      <Input
                        aria-label={t('COMPANIES.DETAIL.PROFILE.FIELDS.NAME')}
                        value={company.name}
                        readOnly
                        inputClassName="h-8 !py-1"
                      />
                      <Input
                        aria-label={t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')}
                        value={company.domain || ''}
                        readOnly
                        inputClassName="h-8 !py-1"
                      />
                    </div>
                    <textarea
                      aria-label={t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')}
                      placeholder={t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')}
                      value={company.description || ''}
                      readOnly
                      rows={3}
                      className="w-full resize-none rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
                    />
                    <Button label={t('COMPANIES.DETAIL.PROFILE.ACTIONS.SAVE')} size="sm" disabled />
                  </div>
                </div>
              )
            )}
          </div>
        </main>
      </div>
    </section>
  )
}
