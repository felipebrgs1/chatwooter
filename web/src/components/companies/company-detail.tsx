// Port de CompaniesDetailsLayout.vue e CompanyDetail/CompanyProfileCard.vue.
// Avatar, contatos, notas e histórico aguardam as respectivas APIs.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import {
  companyQuery,
  companyKeys,
  updateCompany,
  deleteCompany,
  type Company,
  type CompanyInput,
} from '../../api/companies'
import { profileQuery } from '../../api/auth'
import { showAlert } from '../toast/alert'
import { CompaniesDetailsLayout } from './companies-details-layout'
import { CompanySidebar, type CompanyTab } from './company-sidebar'
import { TabBar } from '../next/tab-bar'
import { uploadCompanyAvatar, deleteCompanyAvatar } from '../../api/companies'
import { Dialog } from '../next/dialog'
import { ApiError } from '../../api/client'
import { useAccountId } from '../../api/use-account-id'
import { exactTimestamp, longTimeAgo } from '../../shared/time-ago'
import { Avatar } from '../next/avatar'
import { Button } from '../next/button'
import { Input } from '../next/input'

export function CompanyDetail({
  companyId,
  onBack,
  onContact = () => {},
  onConversation = () => {},
}: {
  companyId: number
  onBack: () => void
  onContact?: (id: number) => void
  onConversation?: (id: number) => void
}) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const queryClient = useQueryClient()
  const { data: profile } = useQuery(profileQuery)
  const isAdmin =
    profile?.accounts.find((account) => account.id === accountId)?.role === 'administrator'
  const query = useQuery(companyQuery(accountId, companyId))
  const [confirmDelete, setConfirmDelete] = useState(false)
  const update = useMutation({
    mutationFn: (data: CompanyInput) => updateCompany(accountId, companyId, data),
    onSuccess: (saved) => {
      queryClient.setQueryData(companyQuery(accountId, companyId).queryKey, saved)
      void queryClient.invalidateQueries({ queryKey: [...companyKeys.all(accountId), 'list'] })
      showAlert(t('COMPANIES.DETAIL.PROFILE.MESSAGES.UPDATE_SUCCESS'))
    },
    onError: () => showAlert(t('COMPANIES.DETAIL.PROFILE.MESSAGES.UPDATE_ERROR')),
  })
  const remove = useMutation({
    mutationFn: () => deleteCompany(accountId, companyId),
    onSuccess: () => {
      queryClient.removeQueries({ queryKey: companyQuery(accountId, companyId).queryKey })
      void queryClient.invalidateQueries({ queryKey: companyKeys.all(accountId) })
      void queryClient.invalidateQueries({ queryKey: ['accounts', accountId, 'contacts'] })
      showAlert(t('COMPANIES.DETAIL.DELETE.MESSAGES.SUCCESS'))
      onBack()
    },
    onError: () => showAlert(t('COMPANIES.DETAIL.DELETE.MESSAGES.ERROR')),
  })
  const [tab, setTab] = useState<CompanyTab>('attributes')
  const avatar = useMutation({
    mutationFn: (file: File) => uploadCompanyAvatar(accountId, companyId, file),
    onSuccess: (saved) => {
      queryClient.setQueryData(companyQuery(accountId, companyId).queryKey, saved)
      void queryClient.invalidateQueries({ queryKey: [...companyKeys.all(accountId), 'list'] })
      showAlert(t('COMPANIES.DETAIL.AVATAR.UPLOAD_SUCCESS'))
    },
    onError: () => showAlert(t('COMPANIES.DETAIL.AVATAR.UPLOAD_ERROR')),
  })
  const deleteAvatar = useMutation({
    mutationFn: () => deleteCompanyAvatar(accountId, companyId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: companyKeys.all(accountId) })
      showAlert(t('COMPANIES.DETAIL.AVATAR.DELETE_SUCCESS'))
    },
    onError: () => showAlert(t('COMPANIES.DETAIL.AVATAR.DELETE_ERROR')),
  })
  const company = query.data
  return (
    <CompaniesDetailsLayout
      name={company?.name}
      onBack={onBack}
      sidebarHeader={
        <div className="px-6 pb-3 pt-6">
          <TabBar
            id="company-tabs"
            tabs={(['attributes', 'contacts', 'history', 'notes'] as const).map((value) => ({
              value,
              label: t(`COMPANIES.DETAIL.SIDEBAR.TABS.${value.toUpperCase()}`),
            }))}
            active={tab}
            onChange={(value) => setTab(value as CompanyTab)}
            className="w-full bg-n-alpha-black2 [&>button]:w-full"
          />
        </div>
      }
      sidebar={
        company ? (
          <CompanySidebar
            key={company.id}
            accountId={accountId}
            company={company}
            tab={tab}
            onContact={onContact}
            onConversation={onConversation}
          />
        ) : null
      }
    >
      {query.isPending ? (
        <span className="text-sm text-n-slate-11">{t('COMPANIES.DETAIL.LOADING')}</span>
      ) : query.isError && !(query.error instanceof ApiError && query.error.status === 404) ? (
        <p role="alert" className="text-center text-n-ruby-11">
          {t('ONBOARDING_INBOX_SETUP.ERROR')}
        </p>
      ) : query.isError ? (
        <div className="text-center">
          <h2 className="text-base text-n-slate-12">{t('COMPANIES.DETAIL.EMPTY_STATE.TITLE')}</h2>
          <p className="text-sm text-n-slate-11">{t('COMPANIES.DETAIL.EMPTY_STATE.SUBTITLE')}</p>
        </div>
      ) : (
        company && (
          <>
            <CompanyProfile
              key={company.id}
              company={company}
              onAvatar={(file) => avatar.mutate(file)}
              onDeleteAvatar={() => deleteAvatar.mutate()}
              avatarBusy={avatar.isPending || deleteAvatar.isPending}
              isUpdating={update.isPending}
              onUpdate={async (data) => {
                try {
                  await update.mutateAsync(data)
                  return true
                } catch {
                  return false
                }
              }}
            />
            {isAdmin && (
              <div className="flex w-full flex-col items-start gap-4 border-t border-n-strong pt-6 pb-6">
                <div className="flex flex-col gap-2">
                  <h6 className="text-base font-medium text-n-slate-12">
                    {t('COMPANIES.DETAIL.DELETE.SECTION_TITLE')}
                  </h6>
                  <span className="text-sm text-n-slate-11">
                    {t('COMPANIES.DETAIL.DELETE.SECTION_DESCRIPTION')}
                  </span>
                </div>
                <Button
                  label={t('COMPANIES.DETAIL.DELETE.BUTTON')}
                  color="ruby"
                  disabled={remove.isPending}
                  onClick={() => setConfirmDelete(true)}
                />
                <Dialog
                  open={confirmDelete}
                  title={t('COMPANIES.DETAIL.DELETE.TITLE')}
                  description={t('COMPANIES.DETAIL.DELETE.DESCRIPTION_WITH_NAME', {
                    companyName: company.name,
                  })}
                  type="alert"
                  confirmLabel={t('COMPANIES.DETAIL.DELETE.CONFIRM')}
                  cancelLabel={t('DIALOG.BUTTONS.CANCEL')}
                  onClose={() => setConfirmDelete(false)}
                  onConfirm={() => {
                    setConfirmDelete(false)
                    remove.mutate()
                  }}
                />
              </div>
            )}
          </>
        )
      )}
    </CompaniesDetailsLayout>
  )
}

function CompanyProfile({
  company,
  isUpdating,
  onUpdate,
  onAvatar,
  onDeleteAvatar,
  avatarBusy,
}: {
  company: Company
  onAvatar: (file: File) => void
  onDeleteAvatar: () => void
  avatarBusy: boolean
  isUpdating: boolean
  onUpdate: (data: CompanyInput) => Promise<boolean>
}) {
  const { t } = useTranslation()
  const avatarInput = useRef<HTMLInputElement>(null)
  const initial = {
    name: company.name,
    domain: company.domain ?? '',
    description: company.description ?? '',
  }
  const [form, setForm] = useState(initial)
  const [source, setSource] = useState(company)
  if (source !== company) {
    setSource(company)
    setForm(initial)
  }
  const changed =
    form.name.trim() !== initial.name.trim() ||
    form.domain.trim() !== initial.domain.trim() ||
    form.description.trim() !== initial.description.trim()
  return (
    <div className="flex flex-col items-start gap-8 pb-6">
      <div className="flex flex-col items-start gap-3">
        <div className="relative group/avatar">
          <Avatar
            name={company.name || t('COMPANIES.UNNAMED')}
            src={company.avatar_url}
            size={72}
          />
          <div className="absolute inset-0 flex items-center justify-center gap-1 rounded-2xl bg-n-alpha-black2 opacity-0 group-hover/avatar:opacity-100 focus-within:opacity-100">
            <Button
              icon="ph-pencil-simple-line"
              size="xs"
              variant="ghost"
              color="slate"
              aria-label={t('PROFILE_SETTINGS.FORM.UPLOAD_IMAGE')}
              disabled={avatarBusy || isUpdating}
              onClick={() => avatarInput.current?.click()}
            />
            {company.avatar_url && (
              <Button
                icon="ph-trash"
                aria-label={t('PROFILE_SETTINGS.DELETE_AVATAR')}
                variant="ghost"
                color="ruby"
                size="xs"
                disabled={avatarBusy || isUpdating}
                onClick={onDeleteAvatar}
              />
            )}
          </div>
          <input
            ref={avatarInput}
            type="file"
            accept="image/png,image/jpeg,image/gif,image/webp"
            aria-label={t('PROFILE_SETTINGS.FORM.AVATAR')}
            className="sr-only"
            disabled={avatarBusy || isUpdating}
            onChange={(event) => {
              const file = event.target.files?.[0]
              if (file) onAvatar(file)
              event.target.value = ''
            }}
          />
        </div>
        <div className="flex flex-col gap-1">
          <h3 className="text-base font-medium text-n-slate-12">{company.name}</h3>
          <span className="text-sm leading-6 text-n-slate-11">
            <span title={exactTimestamp(company.created_at)}>
              {t('COMPANIES.DETAIL.PROFILE.CREATED_AT', { date: longTimeAgo(company.created_at) })}
            </span>
            {company.last_activity_at && (
              <>
                {' '}
                •{' '}
                <span title={exactTimestamp(company.last_activity_at)}>
                  {t('COMPANIES.DETAIL.PROFILE.LAST_ACTIVE', {
                    date: longTimeAgo(company.last_activity_at),
                  })}
                </span>
              </>
            )}
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
            placeholder={t('COMPANIES.DETAIL.PROFILE.FIELDS.NAME')}
            value={form.name}
            disabled={isUpdating}
            inputClassName="h-8 !py-1"
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
          <Input
            aria-label={t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')}
            placeholder={t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')}
            value={form.domain}
            disabled={isUpdating}
            inputClassName="h-8 !py-1"
            onChange={(e) => setForm({ ...form, domain: e.target.value })}
          />
        </div>
        <div className="w-full">
          <textarea
            aria-label={t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')}
            placeholder={t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')}
            value={form.description}
            disabled={isUpdating}
            maxLength={280}
            rows={3}
            className="w-full resize-none rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            onChange={(e) => setForm({ ...form, description: e.target.value })}
          />
          <span className="block text-end text-xs text-n-slate-11">
            {form.description.length}/280
          </span>
        </div>
        <Button
          label={t('COMPANIES.DETAIL.PROFILE.ACTIONS.SAVE')}
          size="sm"
          isLoading={isUpdating}
          disabled={isUpdating || !form.name.trim() || !changed}
          onClick={async () => {
            const saved = await onUpdate({
              name: form.name.trim(),
              domain: form.domain.trim() || null,
              description: form.description.trim() || null,
            })
            if (!saved) setForm(initial)
          }}
        />
      </div>
    </div>
  )
}
