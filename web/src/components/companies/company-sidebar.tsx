// Port de CompanyContactsSidebar.vue, CompanyHistorySidebar.vue e CompanyNotesSidebar.vue.
import { useCallback, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { profileQuery } from '../../api/auth'
import {
  companyContactsQuery,
  companyContactSearchQuery,
  companyConversationsQuery,
  companyNotesQuery,
  linkCompanyContact,
  unlinkCompanyContact,
  companyKeys,
  type Company,
  type CompanyContact,
} from '../../api/companies'
import { inboxesQuery } from '../../api/inboxes'
import { labelsQuery } from '../../api/labels'
import { Avatar } from '../next/avatar'
import { Button } from '../next/button'
import { Combobox } from '../next/combobox'
import { CompactConversationCard } from '../next/conversation-card'
import { PaginationFooter } from '../next/pagination-footer'
import { Spinner } from '../next/spinner'
import { FormattedContent } from '../conversation/formatted-content'
import { exactTimestamp, longTimeAgo } from '../../shared/time-ago'
import { showAlert } from '../toast/alert'
export type CompanyTab = 'attributes' | 'contacts' | 'history' | 'notes'
export function CompanySidebar({
  accountId,
  company,
  tab,
  onContact,
  onConversation,
}: {
  accountId: number
  company: Company
  tab: CompanyTab
  onContact: (id: number) => void
  onConversation: (id: number) => void
}) {
  const { t } = useTranslation()
  const client = useQueryClient()
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<CompanyContact | null>(null)
  const contacts = useQuery({
    ...companyContactsQuery(accountId, company.id, page),
    enabled: tab === 'contacts',
  })
  const found = useQuery({
    ...companyContactSearchQuery(accountId, company.id, search),
    enabled: tab === 'contacts' && !!search.trim(),
  })
  const history = useQuery({
    ...companyConversationsQuery(accountId, company.id),
    enabled: tab === 'history',
  })
  const notes = useQuery({ ...companyNotesQuery(accountId, company.id), enabled: tab === 'notes' })
  const { data: profile } = useQuery(profileQuery)
  const { data: inboxes = [] } = useQuery({
    ...inboxesQuery(accountId),
    enabled: tab === 'history',
  })
  const { data: labels = [] } = useQuery({ ...labelsQuery(accountId), enabled: tab === 'history' })
  const refresh = () => {
    void client.invalidateQueries({ queryKey: companyKeys.all(accountId) })
    void client.invalidateQueries({ queryKey: ['accounts', accountId, 'contacts'] })
  }
  const link = useMutation({
    mutationFn: (id: number) => linkCompanyContact(accountId, company.id, id),
    onSuccess: () => {
      setSelected(null)
      setSearch('')
      refresh()
      showAlert(t('COMPANIES.DETAIL.CONTACTS.MESSAGES.ADD_SUCCESS'))
    },
    onError: () => showAlert(t('COMPANIES.DETAIL.CONTACTS.MESSAGES.ADD_ERROR')),
  })
  const unlink = useMutation({
    mutationFn: (id: number) => unlinkCompanyContact(accountId, company.id, id),
    onSuccess: () => {
      setPage(1)
      refresh()
      showAlert(t('COMPANIES.DETAIL.CONTACTS.MESSAGES.REMOVE_SUCCESS'))
    },
    onError: () => showAlert(t('COMPANIES.DETAIL.CONTACTS.MESSAGES.REMOVE_ERROR')),
  })
  const onSearch = useCallback((value: string) => setSearch(value.trim()), [])
  const empty = (key: string) => (
    <p className="py-8 px-4 mx-6 text-sm text-center rounded-xl border border-dashed border-n-strong text-n-slate-11">
      {t(key)}
    </p>
  )
  if (tab === 'attributes') return empty('COMPANIES.DETAIL.ATTRIBUTES.EMPTY_STATE')
  const loading = (tab === 'history' && history.isPending) || (tab === 'notes' && notes.isPending)
  if (loading)
    return (
      <div className="flex items-center justify-center py-10 text-n-slate-11">
        <Spinner />
      </div>
    )
  if ((history.isError && tab === 'history') || (notes.isError && tab === 'notes'))
    return (
      <p role="alert" className="px-6 text-n-ruby-11">
        {t('ONBOARDING_INBOX_SETUP.ERROR')}
      </p>
    )
  if (tab === 'history')
    return history.data?.length ? (
      <div className="px-6 divide-y divide-n-strong">
        {history.data.map((conversation) => (
          <CompactConversationCard
            key={conversation.id}
            conversation={conversation}
            inbox={inboxes.find((i) => i.id === conversation.inbox_id)}
            accountLabels={labels}
            className="rounded-none hover:rounded-xl hover:bg-n-alpha-1"
            renderLink={({ children, className }) => (
              <button
                type="button"
                className={className}
                onClick={() => onConversation(conversation.id)}
              >
                {children}
              </button>
            )}
          />
        ))}
      </div>
    ) : (
      empty('COMPANIES.DETAIL.HISTORY.EMPTY')
    )
  if (tab === 'notes')
    return notes.data?.length ? (
      <div className="flex flex-col px-6 divide-y divide-n-strong">
        {notes.data.map((note) => (
          <article key={note.id} className="flex flex-col gap-2 py-4">
            <div className="flex items-center gap-1.5 text-sm text-n-slate-11">
              <Avatar name={note.contact.name} size={16} />
              <button
                type="button"
                className="font-medium text-n-slate-12"
                onClick={() => onContact(note.contact.id)}
              >
                {note.contact.name}
              </button>
              <span>
                {note.user?.id === profile?.id
                  ? t('CONTACTS_LAYOUT.SIDEBAR.NOTES.YOU')
                  : note.user?.name}{' '}
                {t('CONTACTS_LAYOUT.SIDEBAR.NOTES.WROTE')}{' '}
                <span title={exactTimestamp(note.created_at)}>{longTimeAgo(note.created_at)}</span>
              </span>
            </div>
            <p className="text-sm text-n-slate-12">
              <FormattedContent content={note.content} />
            </p>
          </article>
        ))}
      </div>
    ) : (
      empty('COMPANIES.DETAIL.NOTES.EMPTY')
    )
  return (
    <div className="flex flex-col gap-6 px-6 pb-8">
      {!selected ? (
        <div className="flex flex-col gap-4">
          <div className="flex flex-col gap-2">
            <label className="text-base text-n-slate-12">
              {t('COMPANIES.DETAIL.CONTACTS.ACTIONS.ADD')}
            </label>
            <span className="text-sm text-n-slate-11">
              {t('COMPANIES.DETAIL.CONTACTS.DIALOGS.ADD.DESCRIPTION')}
            </span>
          </div>
          <Combobox
            id={`company-${company.id}-add-contact`}
            value={null}
            options={(found.data?.payload ?? []).map((contact) => ({
              value: contact.id,
              label: [contact.name, contact.email, contact.phone_number]
                .filter(Boolean)
                .join(' · '),
            }))}
            placeholder={t('COMPANIES.DETAIL.CONTACTS.ACTIONS.ADD')}
            searchPlaceholder={t('COMPANIES.DETAIL.CONTACTS.DIALOGS.ADD.SEARCH_PLACEHOLDER')}
            emptyState={t(
              found.isFetching
                ? 'COMPANIES.DETAIL.CONTACTS.LOADING'
                : search
                  ? 'COMPANIES.DETAIL.CONTACTS.DIALOGS.ADD.EMPTY'
                  : 'COMPANIES.DETAIL.CONTACTS.DIALOGS.ADD.INITIAL',
            )}
            useApiResults
            onSearch={onSearch}
            disabled={link.isPending || unlink.isPending}
            onChange={(id) =>
              setSelected(found.data?.payload.find((ct) => ct.id === Number(id)) ?? null)
            }
          />
          {found.isError && <p role="alert">{t('ONBOARDING_INBOX_SETUP.ERROR')}</p>}
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          <label className="text-base text-n-slate-12">
            {t('COMPANIES.DETAIL.CONTACTS.DIALOGS.ADD.CONFIRM_TITLE')}
          </label>
          <span className="text-sm text-n-slate-11">
            {t('COMPANIES.DETAIL.CONTACTS.DIALOGS.ADD.CONFIRM_DESCRIPTION')}
          </span>
          {[company, selected].map((item, i) => (
            <div
              key={i}
              className="border border-n-strong h-[60px] gap-2 flex items-center rounded-xl p-3"
            >
              <Avatar name={item.name} size={32} />
              <span className="text-sm text-n-slate-12">{item.name}</span>
            </div>
          ))}
          {selected.company && (
            <span className="text-xs text-n-amber-11">
              {t('COMPANIES.DETAIL.CONTACTS.DIALOGS.ADD.CURRENT_COMPANY', {
                companyName: selected.company.name,
              })}
            </span>
          )}
          <div className="flex gap-3">
            <Button
              variant="faded"
              color="slate"
              label={t('DIALOG.BUTTONS.CANCEL')}
              disabled={link.isPending}
              onClick={() => setSelected(null)}
            />
            <Button
              label={t('COMPANIES.DETAIL.CONTACTS.DIALOGS.ADD.ADD')}
              isLoading={link.isPending}
              disabled={link.isPending}
              onClick={() => link.mutate(selected.id)}
            />
          </div>
        </div>
      )}
      <h4 className="text-sm font-medium text-n-slate-12">
        {t('COMPANIES.DETAIL.SIDEBAR.TABS.CONTACTS')}
      </h4>
      {contacts.isError ? (
        <p role="alert">{t('ONBOARDING_INBOX_SETUP.ERROR')}</p>
      ) : contacts.isPending ? (
        <Spinner />
      ) : !contacts.data?.payload.length ? (
        empty('COMPANIES.DETAIL.CONTACTS.EMPTY')
      ) : (
        <div className="flex flex-col divide-y divide-n-weak">
          {contacts.data.payload.map((contact) => (
            <div key={contact.id} className="flex items-center gap-2 py-3 group/contact">
              <button
                type="button"
                className="flex items-center flex-1 min-w-0 gap-3 text-start"
                onClick={() => onContact(contact.id)}
              >
                <Avatar name={contact.name} size={32} />
                <div className="min-w-0">
                  <span className="text-sm font-medium text-n-slate-12">{contact.name}</span>
                  <p className="text-sm text-n-slate-11">
                    {[contact.email, contact.phone_number].filter(Boolean).join(' • ')}
                  </p>
                </div>
              </button>
              <Button
                icon="ph-link"
                variant="ghost"
                color="slate"
                size="xs"
                aria-label={t('COMPANIES.DETAIL.CONTACTS.ACTIONS.REMOVE')}
                disabled={link.isPending || unlink.isPending}
                onClick={() => unlink.mutate(contact.id)}
              />
            </div>
          ))}
        </div>
      )}
      {contacts.data && contacts.data.meta.total_count > 15 && (
        <PaginationFooter
          currentPage={page}
          totalItems={contacts.data.meta.total_count}
          itemsPerPage={15}
          currentPageInfo="CONTACTS_LAYOUT.PAGINATION_FOOTER.SHOWING"
          onPageChange={setPage}
          className="!px-0 before:hidden bg-transparent"
        />
      )}
    </div>
  )
}
