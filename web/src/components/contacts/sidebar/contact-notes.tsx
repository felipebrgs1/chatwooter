// Port de components-next/Contacts/ContactsSidebar/ContactNotes.vue: editor + notas do contato.
import { useTranslation } from 'react-i18next'
import { useState } from 'react'

import type { ContactNote } from '../../../api/types'
import { Button } from '../../next/button'
import { Editor } from '../../next/editor'
import { Spinner } from '../../next/spinner'
import { ContactNoteItem } from './contact-note-item'

type Props = {
  notes: ContactNote[] | undefined
  currentUserId: number
  isCreating: boolean
  onAdd: (content: string) => void
  onDelete: (noteId: number) => void
}

export function ContactNotes({ notes, currentUserId, isCreating, onAdd, onDelete }: Props) {
  const { t } = useTranslation()
  const [message, setMessage] = useState('')

  function add() {
    if (!message) return
    onAdd(message)
    setMessage('')
  }

  const writtenBy = (note: ContactNote) =>
    note.user?.id === currentUserId
      ? t('CONTACTS_LAYOUT.SIDEBAR.NOTES.YOU')
      : note.user?.name || 'Bot'

  return (
    <div className="flex flex-col gap-6">
      <Editor
        value={message}
        onChange={setMessage}
        placeholder={t('CONTACTS_LAYOUT.SIDEBAR.NOTES.PLACEHOLDER')}
        focusOnMount
        className="px-6 [&>div]:!border-transparent [&>div]:px-4 [&>div]:py-4"
        // useKeyboardEvents: $mod+Enter salva
        onKeyDown={(event) => {
          if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
            event.preventDefault()
            add()
          }
        }}
        actions={
          <div className="flex items-center gap-3">
            <Button
              variant="link"
              color="blue"
              size="sm"
              label={t('CONTACTS_LAYOUT.SIDEBAR.NOTES.SAVE')}
              className="hover:no-underline"
              isLoading={isCreating}
              disabled={!message || isCreating}
              onClick={add}
            />
          </div>
        }
      />
      {!notes ? (
        <div className="flex items-center justify-center py-10 text-n-slate-11">
          <Spinner />
        </div>
      ) : notes.length > 0 ? (
        <div>
          {notes.map((note) => (
            <ContactNoteItem
              key={note.id}
              className="mx-6 py-4"
              note={note}
              writtenBy={writtenBy(note)}
              allowDelete
              onDelete={onDelete}
            />
          ))}
        </div>
      ) : (
        <p className="px-6 py-6 text-center text-sm leading-6 text-n-slate-11">
          {t('CONTACTS_LAYOUT.SIDEBAR.NOTES.EMPTY_STATE')}
        </p>
      )}
    </div>
  )
}
