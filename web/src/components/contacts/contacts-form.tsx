// Port de components-next/Contacts/ContactsForm/ContactsForm.vue: dados do contato + redes sociais.
// v1 habilita companies em todas as contas, como as rotas de empresas.
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { CompanySelector } from '../companies/company-selector'
import { countries } from '../../shared/countries'
import { splitName } from '../../shared/split-name'
import { Combobox } from '../next/combobox'
import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { Input } from '../next/input'
import { PhoneNumberInput } from '../next/phone-number-input'

export type SocialProfiles = Record<(typeof SOCIAL_KEYS)[number], string> & Record<string, string>

export type ContactFormData = {
  company_id: number | null
  id: number
  name: string
  email: string
  phone_number: string
  additional_attributes: {
    description: string
    company_name: string
    country_code: string
    country: string
    city: string
    social_profiles: SocialProfiles
  }
}

export type ContactFormSource = {
  company_id?: number | null
  id: number
  name: string
  email: string | null
  phone_number: string | null
  additional_attributes?: Record<string, unknown>
}

type Props = {
  contact: ContactFormSource
  /** Borda sempre visível no detalhe; nos cards, só no foco. */
  isDetailsView?: boolean
  /** Chamado a cada edição com os dados (sem nome/sobrenome separados) e se o formulário está inválido. */
  onChange: (data: ContactFormData, invalid: boolean) => void
}

const SOCIAL_KEYS = [
  'linkedin',
  'facebook',
  'instagram',
  'whatsapp',
  'telegram',
  'tiktok',
  'twitter',
  'github',
] as const

// SOCIAL_CONFIG: os ícones Remix do original desenhados com Phosphor
const SOCIAL_ICONS: Record<(typeof SOCIAL_KEYS)[number], string> = {
  linkedin: 'ph-linkedin-logo-fill',
  facebook: 'ph-facebook-logo-fill',
  instagram: 'ph-instagram-logo',
  whatsapp: 'ph-whatsapp-logo',
  telegram: 'ph-telegram-logo-fill',
  tiktok: 'ph-tiktok-logo-fill',
  twitter: 'ph-x-logo-fill',
  github: 'ph-github-logo-fill',
}

const normalizeWhatsApp = (value: string) => value.replace(/^@+/, '')
// validador `email` do vuelidate (regex copiada como está, com os escapes de controle do RFC): vazio é válido
const EMAIL =
  // oxlint-disable-next-line no-control-regex
  /^(?:[A-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]{2,}(?:[a-z0-9-]*[a-z0-9]{2,})?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])$/i
const validEmail = (value: string) => value === '' || EMAIL.test(value)

type State = ContactFormData & { firstName: string; lastName: string }

// prepareStateBasedOnProps
function initialState(contact: ContactFormSource): State {
  const attrs = (contact.additional_attributes ?? {}) as Record<string, unknown>
  const text = (key: string) => (typeof attrs[key] === 'string' ? (attrs[key] as string) : '')
  const profiles = (attrs.social_profiles ?? {}) as Record<string, string>
  const { firstName, lastName } = splitName(contact.name ?? '')
  const social = Object.fromEntries(SOCIAL_KEYS.map((k) => [k, ''])) as SocialProfiles
  return {
    id: contact.id,
    company_id: contact.company_id ?? null,
    name: contact.name ?? '',
    firstName,
    lastName,
    email: contact.email ?? '',
    phone_number: contact.phone_number ?? '',
    additional_attributes: {
      description: text('description'),
      company_name: text('company_name'),
      country_code: text('country_code'),
      country: text('country'),
      city: text('city'),
      social_profiles: {
        ...social,
        ...profiles,
        telegram: profiles.telegram || text('social_telegram_user_name'),
        whatsapp: normalizeWhatsApp(profiles.whatsapp || text('social_whatsapp_user_name')),
      },
    },
  }
}

export function ContactsForm({ contact, isDetailsView = false, onChange }: Props) {
  const { t } = useTranslation()
  const [state, setState] = useState(() => initialState(contact))
  const [touched, setTouched] = useState({ firstName: false, email: false })
  // outro contato: recomeça do zero (watch em contactData.id)
  const [contactId, setContactId] = useState(contact.id)
  if (contact.id !== contactId) {
    setContactId(contact.id)
    setState(initialState(contact))
    setTouched({ firstName: false, email: false })
  }

  const invalidFirstName = state.firstName.trim() === ''
  const invalidEmail = !validEmail(state.email)

  function update(next: State) {
    setState(next)
    // emitContactUpdate: o pai recebe o nome já junto, sem nome/sobrenome separados
    const { id, name, email, phone_number, additional_attributes, company_id } = next
    onChange(
      { id, name, email, phone_number, additional_attributes, company_id },
      next.firstName.trim() === '' || !validEmail(next.email),
    )
  }
  const setAttr = (key: keyof State['additional_attributes'], value: string) =>
    update({ ...state, additional_attributes: { ...state.additional_attributes, [key]: value } })
  const setName = (first: string, last: string) =>
    update({ ...state, firstName: first, lastName: last, name: `${first} ${last}`.trim() })
  const setSocial = (key: string, value: string) =>
    update({
      ...state,
      additional_attributes: {
        ...state.additional_attributes,
        social_profiles: {
          ...state.additional_attributes.social_profiles,
          [key]: key === 'whatsapp' ? normalizeWhatsApp(value) : value,
        },
      },
    })

  const placeholder = (key: string) =>
    t(`CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`)
  const inputClass = cx('h-8 !pt-1 !pb-1', !isDetailsView && '[&:not(:focus)]:!outline-transparent')

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col items-start gap-2">
        <span className="py-1 text-sm font-medium text-n-slate-12">
          {t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.TITLE')}
        </span>
        <div className="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
          <Input
            value={state.firstName}
            placeholder={placeholder('FIRST_NAME')}
            messageType={touched.firstName && invalidFirstName ? 'error' : 'info'}
            inputClassName={inputClass}
            className="w-full"
            onChange={(e) => {
              setTouched((v) => ({ ...v, firstName: true }))
              setName(e.target.value, state.lastName)
            }}
            onBlur={() => setTouched((v) => ({ ...v, firstName: true }))}
          />
          <Input
            value={state.lastName}
            placeholder={placeholder('LAST_NAME')}
            inputClassName={inputClass}
            className="w-full"
            onChange={(e) => setName(state.firstName, e.target.value)}
          />
          <Input
            value={state.email}
            placeholder={placeholder('EMAIL_ADDRESS')}
            messageType={touched.email && invalidEmail ? 'error' : 'info'}
            inputClassName={inputClass}
            className="w-full"
            onChange={(e) => {
              setTouched((v) => ({ ...v, email: true }))
              update({ ...state, email: e.target.value })
            }}
            onBlur={() => setTouched((v) => ({ ...v, email: true }))}
          />
          <PhoneNumberInput
            value={state.phone_number}
            placeholder={placeholder('PHONE_NUMBER')}
            showBorder={isDetailsView}
            onChange={(value) => update({ ...state, phone_number: value })}
          />
          <Input
            value={state.additional_attributes.city}
            placeholder={placeholder('CITY')}
            inputClassName={inputClass}
            className="w-full"
            onChange={(e) => setAttr('city', e.target.value)}
          />
          <Combobox
            id={`contact-${state.id}-country`}
            options={countries.map(({ name, id }) => ({ label: name, value: id }))}
            value={state.additional_attributes.country_code || null}
            placeholder={placeholder('COUNTRY')}
            searchPlaceholder={t('COMBOBOX.SEARCH_PLACEHOLDER')}
            emptyState={t('COMBOBOX.EMPTY_STATE')}
            className={cx(
              '[&>div>button]:h-8',
              isDetailsView
                ? '[&>div>button]:!bg-n-alpha-black2'
                : '[&>div>button:not(.focused)]:!outline-transparent [&>div>button]:bg-n-alpha-black2',
            )}
            onChange={(value) => {
              // handleCountrySelection: o nome do país vai junto com o código
              const country = countries.find((c) => c.id === value)
              update({
                ...state,
                additional_attributes: {
                  ...state.additional_attributes,
                  country_code: String(value),
                  country: country?.name ?? '',
                },
              })
            }}
          />
          <Input
            value={state.additional_attributes.description}
            placeholder={placeholder('BIO')}
            inputClassName={inputClass}
            className="w-full"
            onChange={(e) => setAttr('description', e.target.value)}
          />
          <CompanySelector
            value={state.company_id}
            selectedName={state.additional_attributes.company_name}
            isDetailsView={isDetailsView}
            onSelect={({ id, name }) =>
              update({
                ...state,
                company_id: id,
                additional_attributes: { ...state.additional_attributes, company_name: name },
              })
            }
          />
        </div>
      </div>
      <div className="flex flex-col items-start gap-2">
        <span className="py-1 text-sm font-medium text-n-slate-12">
          {t('CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.TITLE')}
        </span>
        <div className="flex flex-wrap gap-2">
          {SOCIAL_KEYS.map((key) => {
            const socialPlaceholder = t(
              `CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.FORM.${key.toUpperCase()}.PLACEHOLDER`,
            )
            return (
              <div
                key={key}
                className={cx(
                  'flex h-8 items-center gap-2 rounded-lg bg-n-alpha-2 px-2',
                  isDetailsView ? 'dark:bg-n-solid-2' : 'dark:bg-n-solid-3',
                )}
              >
                <Icon name={SOCIAL_ICONS[key]} className="size-4 flex-shrink-0 text-n-slate-11" />
                <input
                  value={state.additional_attributes.social_profiles[key] ?? ''}
                  placeholder={socialPlaceholder}
                  size={socialPlaceholder.length}
                  className="w-auto min-w-[100px] bg-transparent text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10"
                  onChange={(e) => setSocial(key, e.target.value)}
                />
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
