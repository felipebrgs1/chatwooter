// Port de components-next/Contacts/Pages/ContactDetails.vue (+ ConfirmContactDeleteDialog.vue).
// Upload/remoção de avatar dependem de storage de anexos: o avatar aparece sem as ações.
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import type { ContactListItem, Label } from '../../api/types'
import { exactTimestamp, longTimeAgo } from '../../shared/time-ago'
import { Avatar } from '../next/avatar'
import { Button } from '../next/button'
import { Dialog } from '../next/dialog'
import { Icon } from '../next/icon'
import { ContactLabels } from './contact-labels'
import { ContactsForm, type ContactFormData } from './contacts-form'

type Props = {
  contact: ContactListItem
  labels: string[]
  accountLabels: Label[]
  isUpdating: boolean
  /** Policy permissions=['administrator']: só o admin vê a exclusão. */
  isAdmin: boolean
  onLabelsChange: (titles: string[]) => void
  onUpdate: (data: ContactFormData) => void
  onDelete: () => void
}

export function ContactDetails({
  contact,
  labels,
  accountLabels,
  isUpdating,
  isAdmin,
  onLabelsChange,
  onUpdate,
  onDelete,
}: Props) {
  const { t } = useTranslation()
  const [form, setForm] = useState<{ data: ContactFormData | null; invalid: boolean }>({
    data: null,
    invalid: false,
  })
  const [confirmDelete, setConfirmDelete] = useState(false)

  return (
    <div className="flex flex-col items-start gap-8 pb-6">
      <div className="flex flex-col items-start gap-3">
        <Avatar name={contact.name || ''} size={72} />
        <div className="flex flex-col gap-1">
          <h3 className="text-base font-medium text-n-slate-12">{contact.name}</h3>
          <div className="flex flex-col gap-1.5">
            {contact.identifier && (
              <span className="inline-flex items-center gap-1 text-sm text-n-slate-11">
                <Icon name="ph-user-gear" className="size-4 text-n-slate-10" />
                {contact.identifier}
              </span>
            )}
            <span className="inline-flex items-center gap-1 text-sm text-n-slate-11">
              {contact.identifier && <Icon name="ph-pulse" className="size-4 text-n-slate-10" />}
              <span title={exactTimestamp(contact.created_at)}>
                {t('CONTACTS_LAYOUT.DETAILS.CREATED_AT', { date: longTimeAgo(contact.created_at) })}
              </span>
              •
              <span title={exactTimestamp(contact.last_activity_at)}>
                {t('CONTACTS_LAYOUT.DETAILS.LAST_ACTIVITY', {
                  date: longTimeAgo(contact.last_activity_at),
                })}
              </span>
            </span>
          </div>
        </div>
        <ContactLabels labels={labels} accountLabels={accountLabels} onChange={onLabelsChange} />
      </div>
      <div className="flex flex-col items-start gap-6">
        <ContactsForm
          contact={contact}
          isDetailsView
          onChange={(data, invalid) => setForm({ data, invalid })}
        />
        <Button
          label={t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')}
          size="sm"
          isLoading={isUpdating}
          disabled={isUpdating || form.invalid}
          onClick={() => form.data && onUpdate(form.data)}
        />
      </div>
      {isAdmin && (
        <>
          <div className="flex w-full flex-col items-start gap-4 border-t border-n-strong pt-6">
            <div className="flex flex-col gap-2">
              <h6 className="text-base font-medium text-n-slate-12">
                {t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT')}
              </h6>
              <span className="text-sm text-n-slate-11">
                {t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT_DESCRIPTION')}
              </span>
            </div>
            <Button
              label={t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT')}
              color="ruby"
              onClick={() => setConfirmDelete(true)}
            />
          </div>
          <Dialog
            open={confirmDelete}
            type="alert"
            title={t('CONTACTS_LAYOUT.DETAILS.DELETE_DIALOG.TITLE')}
            description={t('CONTACTS_LAYOUT.DETAILS.DELETE_DIALOG.DESCRIPTION')}
            confirmLabel={t('CONTACTS_LAYOUT.DETAILS.DELETE_DIALOG.CONFIRM')}
            cancelLabel={t('DIALOG.BUTTONS.CANCEL')}
            onClose={() => setConfirmDelete(false)}
            onConfirm={() => {
              setConfirmDelete(false)
              onDelete()
            }}
          />
        </>
      )}
    </div>
  )
}
