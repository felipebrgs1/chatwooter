// Port de routes/dashboard/contacts/pages/ContactManageView.vue: detalhe do contato + abas laterais.
// Abas Media (anexos das conversas) e Merge (ContactMerge) entram quando houver backend para elas; Attributes
// mostra o estado vazio enquanto não existem custom_attribute_definitions.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { profileQuery } from '../../api/auth'
import { ApiError } from '../../api/client'
import {
  contactConversationsQuery,
  contactKeys,
  contactLabelsQuery,
  contactNotesQuery,
  contactQuery,
  createContactNote,
  deleteContact,
  deleteContactNote,
  updateContact,
  updateContactLabels,
  type ContactUpdate,
} from '../../api/contacts'
import { inboxesQuery } from '../../api/inboxes'
import { labelsQuery } from '../../api/labels'
import type { Conversation } from '../../api/types'
import { useAccountId } from '../../api/use-account-id'
import { CompactConversationCard } from '../next/conversation-card'
import { Spinner } from '../next/spinner'
import { TabBar } from '../next/tab-bar'
import { showAlert } from '../toast/alert'
import { ContactDetails } from './contact-details'
import { ContactsDetailsLayout } from './contacts-details-layout'
import { ContactNotes } from './sidebar/contact-notes'

const TABS = [
  { key: 'ATTRIBUTES', value: 'attributes' },
  { key: 'HISTORY', value: 'history' },
  { key: 'NOTES', value: 'notes' },
] as const
type Tab = (typeof TABS)[number]['value']

type Props = {
  contactId: number
  onGoToContactsList: () => void
  renderConversationLink: (
    conversation: Conversation,
    props: { className: string; children: ReactNode },
  ) => ReactNode
}

// O front do Chatwoot (DuplicateContactException) olha se a mensagem cita email ou phone_number
function updateErrorMessage(error: unknown, t: (key: string) => string) {
  const prefix = 'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM'
  const text = error instanceof ApiError ? error.messages.join(' ') : ''
  if (/email/i.test(text)) return t(`${prefix}.FORM.EMAIL_ADDRESS.DUPLICATE`)
  if (/phone/i.test(text)) return t(`${prefix}.FORM.PHONE_NUMBER.DUPLICATE`)
  return t(`${prefix}.ERROR_MESSAGE`)
}

export function ContactManageView({
  contactId,
  onGoToContactsList,
  renderConversationLink,
}: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<Tab>('attributes')

  const { data: profile } = useQuery(profileQuery)
  const contact = useQuery(contactQuery(accountId, contactId))
  const labels = useQuery(contactLabelsQuery(accountId, contactId))
  const notes = useQuery(contactNotesQuery(accountId, contactId))
  const conversations = useQuery(contactConversationsQuery(accountId, contactId))
  const { data: accountLabels = [] } = useQuery(labelsQuery(accountId))
  const { data: inboxes = [] } = useQuery(inboxesQuery(accountId))

  const detailKey = contactKeys.detail(accountId, contactId)
  const refreshLists = () =>
    void queryClient.invalidateQueries({ queryKey: [...contactKeys.all(accountId), 'list'] })

  const update = useMutation({
    mutationFn: (data: ContactUpdate) => updateContact(accountId, contactId, data),
    onSuccess: (saved) => {
      queryClient.setQueryData(detailKey, saved)
      refreshLists()
    },
  })

  const membership = profile?.accounts.find((a) => a.id === accountId)
  const isAdmin = membership?.role === 'administrator'

  async function onUpdate(data: ContactUpdate) {
    try {
      await update.mutateAsync(data)
      showAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE'))
    } catch (error) {
      showAlert(updateErrorMessage(error, t))
    }
  }

  async function onToggleBlock(blocked: boolean) {
    try {
      await update.mutateAsync({ blocked: !blocked })
      showAlert(
        blocked
          ? t('CONTACTS_LAYOUT.HEADER.ACTIONS.UNBLOCK_SUCCESS_MESSAGE')
          : t('CONTACTS_LAYOUT.HEADER.ACTIONS.BLOCK_SUCCESS_MESSAGE'),
      )
    } catch {
      showAlert(
        blocked
          ? t('CONTACTS_LAYOUT.HEADER.ACTIONS.UNBLOCK_ERROR_MESSAGE')
          : t('CONTACTS_LAYOUT.HEADER.ACTIONS.BLOCK_ERROR_MESSAGE'),
      )
    }
  }

  async function onLabelsChange(titles: string[]) {
    try {
      const saved = await updateContactLabels(accountId, contactId, titles)
      queryClient.setQueryData(contactLabelsQuery(accountId, contactId).queryKey, saved)
    } catch {
      // o original engole o erro (ContactLabels.vue)
    }
  }

  // ConfirmContactDeleteDialog: volta para a lista e apaga
  async function onDelete() {
    onGoToContactsList()
    try {
      await deleteContact(accountId, contactId)
      queryClient.removeQueries({ queryKey: detailKey })
      refreshLists()
      showAlert(t('CONTACTS_LAYOUT.DETAILS.DELETE_DIALOG.API.SUCCESS_MESSAGE'))
    } catch {
      showAlert(t('CONTACTS_LAYOUT.DETAILS.DELETE_DIALOG.API.ERROR_MESSAGE'))
    }
  }

  const addNote = useMutation({
    mutationFn: (content: string) => createContactNote(accountId, contactId, content),
    onSuccess: () => void notes.refetch(),
  })
  const removeNote = useMutation({
    mutationFn: (noteId: number) => deleteContactNote(accountId, contactId, noteId),
    onSuccess: () => void notes.refetch(),
  })

  const selected = contact.data

  return (
    <div className="m-0 flex h-full flex-1 flex-col justify-between overflow-auto bg-n-surface-1">
      <ContactsDetailsLayout
        contactName={selected?.name}
        blocked={selected?.blocked}
        isUpdating={update.isPending}
        onGoToContactsList={onGoToContactsList}
        onToggleBlock={(blocked) => void onToggleBlock(blocked)}
        sidebarHeader={
          <div className="px-6 pb-3 pt-6">
            <TabBar
              id="contact-tabs"
              tabs={TABS.map((tab) => ({
                value: tab.value,
                label: t(`CONTACTS_LAYOUT.SIDEBAR.TABS.${tab.key}`),
              }))}
              active={activeTab}
              onChange={(value) => setActiveTab(value as Tab)}
              className="w-full bg-n-alpha-black2 [&>button]:w-full"
            />
          </div>
        }
        sidebar={
          contact.isPending ? (
            <div className="flex items-center justify-center py-10 text-n-slate-11">
              <Spinner />
            </div>
          ) : activeTab === 'attributes' ? (
            <p className="px-6 py-10 text-center text-sm leading-6 text-n-slate-11">
              {t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.EMPTY_STATE')}
            </p>
          ) : activeTab === 'notes' ? (
            <ContactNotes
              notes={notes.data}
              currentUserId={profile?.id ?? 0}
              isCreating={addNote.isPending}
              onAdd={(content) => addNote.mutate(content)}
              onDelete={(noteId) => removeNote.mutate(noteId)}
            />
          ) : conversations.isPending ? (
            <div className="flex items-center justify-center py-10 text-n-slate-11">
              <Spinner />
            </div>
          ) : (conversations.data ?? []).length > 0 ? (
            <div className="divide-y divide-n-strong px-6 [&>*:hover+*]:!border-t-transparent [&>*:hover]:!border-y-transparent">
              {conversations.data!.map((conversation) => (
                <CompactConversationCard
                  key={conversation.id}
                  conversation={conversation}
                  inbox={inboxes.find((i) => i.id === conversation.inbox_id)}
                  accountLabels={accountLabels}
                  className="rounded-none hover:rounded-xl hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3"
                  renderLink={(props) => renderConversationLink(conversation, props)}
                />
              ))}
            </div>
          ) : (
            <p className="px-6 py-10 text-center text-sm leading-6 text-n-slate-11">
              {t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.EMPTY_STATE')}
            </p>
          )
        }
      >
        {contact.isPending ? (
          <div className="flex items-center justify-center py-10 text-n-slate-11">
            <Spinner />
          </div>
        ) : selected ? (
          <ContactDetails
            contact={selected}
            labels={labels.data ?? []}
            accountLabels={accountLabels}
            isUpdating={update.isPending}
            isAdmin={isAdmin}
            onLabelsChange={(titles) => void onLabelsChange(titles)}
            onUpdate={(data) => void onUpdate(data)}
            onDelete={() => void onDelete()}
          />
        ) : null}
      </ContactsDetailsLayout>
    </div>
  )
}
