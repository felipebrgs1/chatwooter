// Port de components-next/Contacts/ContactsSidebar/components/ContactNoteItem.vue (sem o modo "collapsible",
// que só a conversa usa).
import { useTranslation } from 'react-i18next'

import type { ContactNote } from '../../../api/types'
import { exactTimestamp, longTimeAgo } from '../../../shared/time-ago'
import { FormattedContent } from '../../conversation/formatted-content'
import { Avatar } from '../../next/avatar'
import { Button } from '../../next/button'

type Props = {
  note: ContactNote
  writtenBy: string
  allowDelete?: boolean
  onDelete?: (id: number) => void
  className?: string
}

export function ContactNoteItem({
  note,
  writtenBy,
  allowDelete = false,
  onDelete,
  className,
}: Props) {
  const { t } = useTranslation()
  return (
    <article
      className={`group/note flex flex-col gap-2 border-b border-n-strong ${className ?? ''}`}
    >
      <div className="flex items-center justify-between gap-2">
        <div className="flex min-w-0 items-center gap-1.5">
          <Avatar name={note.user?.name || 'Bot'} size={16} />
          <div className="min-w-0 truncate">
            <span className="inline-flex items-center gap-1 text-sm text-n-slate-11">
              <span className="font-medium text-n-slate-12">{writtenBy}</span>
              {t('CONTACTS_LAYOUT.SIDEBAR.NOTES.WROTE')}
              <span title={exactTimestamp(note.created_at)} className="font-medium text-n-slate-12">
                {longTimeAgo(note.created_at)}
              </span>
            </span>
          </div>
        </div>
        {allowDelete && (
          <Button
            variant="faded"
            color="ruby"
            size="xs"
            icon="ph-trash"
            className="opacity-0 group-hover/note:opacity-100 focus-visible:opacity-100"
            onClick={() => onDelete?.(note.id)}
          />
        )}
      </div>
      <p className="mb-0 text-sm leading-relaxed text-n-slate-12">
        <FormattedContent content={note.content || ''} />
      </p>
    </article>
  )
}
