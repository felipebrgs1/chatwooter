// Port de components-next/Contacts/ContactsCard/ContactsCard.vue.
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import type { ContactUpdate } from '../../api/contacts'
import { countries } from '../../shared/countries'
import { Avatar } from '../next/avatar'
import { Button } from '../next/button'
import { CardLayout } from '../next/card-layout'
import { Dialog } from '../next/dialog'
import { cx } from '../next/cx'
import { Flag } from '../next/flag'
import { Icon } from '../next/icon'
import { ContactsForm, type ContactFormData } from './contacts-form'

export type ContactCardData = {
  company_id?: number | null
  id: number
  name: string
  email: string | null
  phone_number: string | null
  additional_attributes?: Record<string, unknown>
}

type Props = {
  contact: ContactCardData
  isExpanded?: boolean
  isUpdating?: boolean
  isAdmin?: boolean
  onToggle?: () => void
  onUpdate?: (data: ContactUpdate) => void
  onDelete?: () => void
  onShowContact?: (id: number) => void
}

const byId = new Map(countries.map((c) => [c.id, c]))

// countryDetails: o país pode vir pelo nome gravado (country) ou pelo código (country_code)
function location(attributes: Record<string, unknown>) {
  const {
    country,
    country_code: countryCode,
    city,
  } = attributes as Record<string, string | undefined>
  if (!country && !countryCode) return null
  const found = (country && byId.get(country)) || (countryCode && byId.get(countryCode))
  if (!found) return null
  return { code: found.id, text: [city ? `${city},` : null, found.name].filter(Boolean).join(' ') }
}

export function ContactsCard({
  contact,
  onShowContact,
  isExpanded = false,
  isUpdating = false,
  isAdmin = false,
  onToggle,
  onUpdate,
  onDelete,
}: Props) {
  const { t } = useTranslation()
  const [form, setForm] = useState<{ data: ContactFormData | null; invalid: boolean }>({
    data: null,
    invalid: false,
  })
  const [wasExpanded, setWasExpanded] = useState(isExpanded)
  if (wasExpanded !== isExpanded) {
    setWasExpanded(isExpanded)
    setForm({ data: null, invalid: false })
  }
  const [showDelete, setShowDelete] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const attributes = contact.additional_attributes ?? {}
  const companyName = typeof attributes.company_name === 'string' ? attributes.company_name : ''
  const place = location(attributes)

  return (
    <CardLayout
      layout="row"
      after={
        <div
          id={`contact-${contact.id}-edit`}
          className={cx(
            'transition-all duration-500 ease-in-out grid overflow-hidden',
            isExpanded ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0',
          )}
        >
          <div className="overflow-hidden">
            {isExpanded && (
              <>
                <div className="flex flex-col gap-6 p-6 border-t border-n-strong">
                  <ContactsForm
                    contact={contact}
                    onChange={(data, invalid) => setForm({ data, invalid })}
                  />
                  <div>
                    <Button
                      label={t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')}
                      size="sm"
                      isLoading={isUpdating}
                      disabled={isUpdating || form.invalid || (!contact.name.trim() && !form.data)}
                      onClick={() =>
                        onUpdate?.(
                          form.data ?? {
                            ...contact,
                            email: contact.email ?? '',
                            phone_number: contact.phone_number ?? '',
                          },
                        )
                      }
                    />
                  </div>
                </div>
                {isAdmin && (
                  <div className="flex flex-col items-start border-t border-n-strong px-6 py-5">
                    <Button
                      label={t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT')}
                      icon="ph-caret-down"
                      trailingIcon
                      variant="link"
                      color="slate"
                      size="sm"
                      className="hover:!no-underline text-n-slate-12"
                      aria-expanded={showDelete}
                      onClick={() => setShowDelete(!showDelete)}
                    />
                    {showDelete && (
                      <span className="inline-flex text-n-slate-11 text-sm items-center gap-1 mt-2">
                        {t('CONTACTS_LAYOUT.CARD.DELETE_CONTACT.MESSAGE')}
                        <Button
                          label={t('CONTACTS_LAYOUT.CARD.DELETE_CONTACT.BUTTON')}
                          size="sm"
                          color="ruby"
                          variant="link"
                          onClick={() => setConfirmDelete(true)}
                        />
                      </span>
                    )}
                  </div>
                )}
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
                    onDelete?.()
                  }}
                />
              </>
            )}
          </div>
        </div>
      }
    >
      <div className="flex flex-1 items-center justify-start gap-4">
        <div className="relative">
          <Avatar name={contact.name} size={42} />
        </div>
        <div className="flex flex-1 flex-col gap-0.5">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
            <span className="truncate text-base font-medium text-n-slate-12">{contact.name}</span>
            <span className="inline-flex items-center gap-1">
              {companyName && (
                <>
                  <Icon name="ph-buildings-light" className="mb-0.5 size-4 text-n-slate-10" />
                  <span className="truncate text-sm text-n-slate-11">{companyName}</span>
                </>
              )}
            </span>
          </div>
          <div className="flex flex-wrap items-center justify-start gap-x-3 gap-y-1">
            {contact.email && (
              <>
                <div className="max-w-72 truncate" title={contact.email}>
                  <span className="text-sm text-n-slate-11">{contact.email}</span>
                </div>
                <div className="h-3 w-px truncate bg-n-slate-6" />
              </>
            )}
            {contact.phone_number && (
              <>
                <span className="truncate text-sm text-n-slate-11">{contact.phone_number}</span>
                <div className="h-3 w-px truncate bg-n-slate-6" />
              </>
            )}
            {place && (
              <>
                <span className="inline-flex items-center gap-2 truncate text-sm text-n-slate-11">
                  <Flag country={place.code} className="size-3.5" />
                  {place.text}
                </span>
                <div className="h-3 w-px truncate bg-n-slate-6" />
              </>
            )}
            <Button
              label={t('CONTACTS_LAYOUT.CARD.VIEW_DETAILS')}
              variant="link"
              size="xs"
              onClick={() => onShowContact?.(contact.id)}
            />
          </div>
        </div>
      </div>
      <Button
        icon="ph-caret-down"
        variant="ghost"
        color="slate"
        size="xs"
        aria-label={t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.TITLE')}
        aria-expanded={isExpanded}
        aria-controls={`contact-${contact.id}-edit`}
        className={isExpanded ? 'rotate-180' : undefined}
        onClick={() => {
          setForm({ data: null, invalid: false })
          onToggle?.()
        }}
      />
    </CardLayout>
  )
}
