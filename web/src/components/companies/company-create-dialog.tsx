// Port de components-next/Companies/CompanyCreateDialog.vue.
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import type { CompanyInput } from '../../api/companies'
import { Button } from '../next/button'
import { Dialog } from '../next/dialog'
import { Input } from '../next/input'

type Props = {
  isLoading: boolean
  error?: string
  onClose: () => void
  onCreate: (company: CompanyInput) => void
}
export function CompanyCreateDialog({ isLoading, error, onClose, onCreate }: Props) {
  const { t } = useTranslation()
  const [name, setName] = useState('')
  const [domain, setDomain] = useState('')
  const [description, setDescription] = useState('')
  const invalid = !name.trim() || isLoading
  const submit = () => {
    if (invalid) return
    onCreate({
      name: name.trim(),
      domain: domain.trim() || null,
      description: description.trim() || null,
    })
  }
  return (
    <Dialog
      open
      onClose={onClose}
      onConfirm={submit}
      closeOnConfirm={false}
      width="max-w-3xl"
      title={t('COMPANIES.CREATE.TITLE')}
      confirmLabel={t('COMPANIES.CREATE.ACTIONS.SAVE')}
      cancelLabel={t('DIALOG.BUTTONS.CANCEL')}
      footer={
        <div className="flex w-full items-center justify-between gap-3">
          <Button
            label={t('DIALOG.BUTTONS.CANCEL')}
            variant="link"
            type="button"
            className="h-10 hover:!no-underline hover:text-n-brand"
            onClick={onClose}
          />
          <Button
            label={t('COMPANIES.CREATE.ACTIONS.SAVE')}
            type="submit"
            disabled={invalid}
            isLoading={isLoading}
          />
        </div>
      }
    >
      <div className="flex flex-col gap-6">
        <div className="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
          <Input
            aria-label={t('COMPANIES.DETAIL.PROFILE.FIELDS.NAME')}
            placeholder={t('COMPANIES.DETAIL.PROFILE.FIELDS.NAME')}
            value={name}
            onChange={(e) => setName(e.target.value)}
            disabled={isLoading}
            autoFocus
            inputClassName="h-8 !py-1"
          />
          <Input
            aria-label={t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')}
            placeholder={t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')}
            value={domain}
            onChange={(e) => setDomain(e.target.value)}
            disabled={isLoading}
            inputClassName="h-8 !py-1"
          />
        </div>
        <div className="flex w-full flex-col gap-1">
          <textarea
            aria-label={t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')}
            placeholder={t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            disabled={isLoading}
            maxLength={280}
            rows={3}
            className="w-full resize-none rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          />
          <span className="text-end text-xs text-n-slate-11">{description.length}/280</span>
        </div>
        {error && (
          <p role="alert" className="text-sm text-n-ruby-11">
            {error}
          </p>
        )}
      </div>
    </Dialog>
  )
}
