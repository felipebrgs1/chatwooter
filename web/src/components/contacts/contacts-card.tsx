// Port de components-next/Contacts/ContactsCard/ContactsCard.vue (linha recolhida).
// O chevron abre o formulário de edição rápida e a seção de exclusão, que entram com a edição de contato.
import { useTranslation } from 'react-i18next'

import { countries } from '../../shared/countries'
import { Avatar } from '../next/avatar'
import { Button } from '../next/button'
import { CardLayout } from '../next/card-layout'
import { Flag } from '../next/flag'
import { Icon } from '../next/icon'

export type ContactCardData = {
  id: number
  name: string
  email: string | null
  phone_number: string | null
  additional_attributes?: Record<string, unknown>
}

type Props = {
  contact: ContactCardData
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

export function ContactsCard({ contact, onShowContact }: Props) {
  const { t } = useTranslation()
  const attributes = contact.additional_attributes ?? {}
  const companyName = typeof attributes.company_name === 'string' ? attributes.company_name : ''
  const place = location(attributes)

  return (
    <CardLayout layout="row">
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
      {/* chevron de edição rápida: só visual até existir PUT /contacts/:id */}
      <Button icon="ph-caret-down" variant="ghost" color="slate" size="xs" />
    </CardLayout>
  )
}
