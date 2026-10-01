// Port de routes/dashboard/conversation/contact/ContactInfo.vue (+ ContactInfoRow.vue e SocialIcons.vue):
// o topo do painel com os dados do contato. Por ora só leitura: a edição inline e os modais de nova mensagem,
// editar, mesclar e excluir aparecem só visuais (entram na próxima fatia do painel).
import { useTranslation } from 'react-i18next'

import type { Contact } from '../../../api/types'
import { Avatar } from '../../next/avatar'
import { Button } from '../../next/button'
import { Flag } from '../../next/flag'
import { Icon } from '../../next/icon'
import { showAlert } from '../../toast/alert'

type Props = { contact: Contact }

const SOCIAL_LINKS = [
  { key: 'facebook', icon: 'ph-facebook-logo', link: 'https://facebook.com/' },
  { key: 'twitter', icon: 'ph-x-logo', link: 'https://twitter.com/' },
  { key: 'linkedin', icon: 'ph-linkedin-logo', link: 'https://linkedin.com/' },
  { key: 'github', icon: 'ph-github-logo', link: 'https://github.com/' },
  { key: 'instagram', icon: 'ph-instagram-logo', link: 'https://instagram.com/' },
  { key: 'telegram', icon: 'ph-telegram-logo', link: 'https://t.me/' },
  { key: 'tiktok', icon: 'ph-tiktok-logo', link: 'https://tiktok.com/@' },
]

type RowProps = {
  value?: string | null
  icon: string
  title: string
  href?: string
  showCopy?: boolean
}

function ContactInfoRow({ value, icon, title, href, showCopy }: RowProps) {
  const { t } = useTranslation()
  const content = (
    <>
      <Icon name={icon} className="size-3.5 flex-shrink-0 ltr:ml-1 rtl:mr-1" />
      {value ? (
        <span className="overflow-hidden text-sm whitespace-nowrap text-ellipsis" title={value}>
          {value}
        </span>
      ) : (
        <span className="text-sm text-n-slate-11">{t('CONTACT_PANEL.NOT_AVAILABLE')}</span>
      )}
    </>
  )
  const copy = showCopy && value && (
    <Button
      variant="ghost"
      size="xs"
      color="slate"
      icon="ph-clipboard"
      aria-label={title}
      className="ltr:-ml-1 rtl:-mr-1"
      onClick={async (event) => {
        event.preventDefault()
        try {
          await navigator.clipboard.writeText(value)
          showAlert(t('CONTACT_PANEL.COPY_SUCCESSFUL'))
        } catch {
          // sem permissão de área de transferência: nada a fazer
        }
      }}
    />
  )
  return (
    <div className="group/row w-full h-5 ltr:-ml-1 rtl:-mr-1 flex items-center gap-2">
      {href && value ? (
        <a href={href} className="flex items-center gap-2 text-n-slate-11 hover:underline min-w-0">
          {content}
        </a>
      ) : (
        <div className="flex items-center gap-2 text-n-slate-11 min-w-0">{content}</div>
      )}
      {copy}
    </div>
  )
}

function str(value: unknown) {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : ''
}

export function ContactInfo({ contact }: Props) {
  const { t } = useTranslation()
  const attrs = contact.additional_attributes ?? {}
  const cityAndCountry = [str(attrs.city), str(attrs.country)].filter(Boolean).join(', ')
  const countryCode = str(attrs.country_code)
  const location = str(attrs.location)
  const profiles = (attrs.social_profiles ?? {}) as Record<string, string>
  const social: Record<string, string> = {
    ...profiles,
    twitter: profiles.twitter || str(attrs.screen_name),
    telegram: profiles.telegram || str(attrs.social_telegram_user_name),
  }
  const whatsapp = (profiles.whatsapp || str(attrs.social_whatsapp_user_name)).replace(/^@+/, '')
  const socials = SOCIAL_LINKS.filter((s) => !!social[s.key])
  const createdAt = contact.created_at ? new Date(contact.created_at * 1000).toLocaleString() : ''

  return (
    <div className="relative items-center w-full p-4 pb-3 border-b border-solid border-n-weak">
      <div className="flex flex-col w-full gap-2 text-left rtl:text-right">
        <div className="flex flex-row justify-between">
          <Avatar src={contact.thumbnail} name={contact.name} size={48} />
        </div>
        <div className="flex flex-col items-start gap-1.5 min-w-0 w-full">
          <div className="flex items-center w-full min-w-0 gap-2">
            <h3 className="flex-shrink max-w-full min-w-0 my-0 text-base capitalize break-words text-n-slate-12">
              {contact.name}
            </h3>
            <div className="flex flex-row items-center gap-2">
              {createdAt && (
                <span title={`${t('CONTACT_PANEL.CREATED_AT_LABEL')} ${createdAt}`}>
                  <Icon name="ph-info" className="text-sm text-n-slate-10" />
                </span>
              )}
              {/* contactProfileLink: abre o contato numa aba nova */}
              <a
                href={`/app/contacts/${contact.id}`}
                target="_blank"
                rel="noopener nofollow noreferrer"
                className="leading-3"
              >
                <Icon name="ph-arrow-square-out" className="text-sm text-n-slate-10" />
              </a>
            </div>
          </div>
          {str(attrs.description) && <p className="break-words mb-0.5">{str(attrs.description)}</p>}
          <div className="flex flex-col items-start w-full gap-2">
            <ContactInfoRow
              href={contact.email ? `mailto:${contact.email}` : ''}
              value={contact.email}
              icon="ph-envelope"
              title={t('CONTACT_PANEL.EMAIL_ADDRESS')}
              showCopy
            />
            <ContactInfoRow
              href={contact.phone_number ? `tel:${contact.phone_number}` : ''}
              value={contact.phone_number}
              icon="ph-phone"
              title={t('CONTACT_PANEL.PHONE_NUMBER')}
              showCopy
            />
            {whatsapp && (
              <ContactInfoRow
                value={`@${whatsapp}`}
                icon="ph-whatsapp-logo"
                title={t('CONTACT_PANEL.WHATSAPP_USERNAME')}
                showCopy
              />
            )}
            {contact.identifier && (
              <ContactInfoRow
                value={contact.identifier}
                icon="ph-identification-card"
                title={t('CONTACT_PANEL.IDENTIFIER')}
              />
            )}
            <ContactInfoRow
              value={str(attrs.company_name)}
              icon="ph-bank"
              title={t('CONTACT_PANEL.COMPANY')}
            />
            {(cityAndCountry || location) && (
              <div className="group/row w-full h-5 ltr:-ml-1 rtl:-mr-1 flex items-center gap-2 text-n-slate-11">
                <Icon name="ph-map-trifold" className="size-3.5 flex-shrink-0 ltr:ml-1 rtl:mr-1" />
                <span className="overflow-hidden text-sm whitespace-nowrap text-ellipsis">
                  {cityAndCountry
                    ? countryCode
                      ? cityAndCountry
                      : `${cityAndCountry} 🌎`
                    : location}
                </span>
                {cityAndCountry && countryCode && (
                  <Flag country={countryCode} className="size-3.5" />
                )}
              </div>
            )}
            {socials.length > 0 && (
              <div className="flex items-end gap-3 mx-0 my-2">
                {socials.map((profile) => (
                  <a
                    key={profile.key}
                    href={`${profile.link}${social[profile.key]}`}
                    target="_blank"
                    rel="noopener noreferrer nofollow"
                    aria-label={profile.key}
                  >
                    <Icon
                      name={profile.icon}
                      className="size-4 text-n-slate-11 hover:text-n-slate-10"
                    />
                  </a>
                ))}
              </div>
            )}
          </div>
        </div>
        {/* nova mensagem, editar, mesclar e excluir: só visuais até os modais serem portados */}
        <div className="flex items-center w-full mt-0.5 gap-2">
          <Button
            icon="ph-chat-circle-dots"
            color="slate"
            variant="faded"
            size="sm"
            disabled
            title={t('CONTACT_PANEL.NEW_MESSAGE')}
            aria-label={t('CONTACT_PANEL.NEW_MESSAGE')}
          />
          <Button
            icon="ph-pencil-simple"
            color="slate"
            variant="faded"
            size="sm"
            disabled
            title={t('EDIT_CONTACT.BUTTON_LABEL')}
            aria-label={t('EDIT_CONTACT.BUTTON_LABEL')}
          />
          <Button
            icon="ph-arrows-merge"
            color="slate"
            variant="faded"
            size="sm"
            disabled
            title={t('CONTACT_PANEL.MERGE_CONTACT')}
            aria-label={t('CONTACT_PANEL.MERGE_CONTACT')}
          />
          <Button
            icon="ph-trash"
            color="ruby"
            variant="faded"
            size="sm"
            disabled
            title={t('DELETE_CONTACT.BUTTON_LABEL')}
            aria-label={t('DELETE_CONTACT.BUTTON_LABEL')}
          />
        </div>
      </div>
    </div>
  )
}
