// Port de components/widgets/conversation/conversationBulkActions/BulkUpdateActions.vue.
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import type { ConversationStatus } from '../../../api/types'
import { Button } from '../../next/button'
import { DropdownMenu } from '../../next/dropdown-menu'
import { Icon } from '../../next/icon'
import { useClickOutside } from '../../next/use-click-outside'

type Props = {
  showResolve: boolean
  showReopen: boolean
  showSnooze: boolean
  onUpdate: (status: ConversationStatus) => void
}

type Item = { value: ConversationStatus; label: string; icon: string }

export function BulkUpdateActions({ showResolve, showReopen, showSnooze, onUpdate }: Props) {
  const { t } = useTranslation()
  const ref = useRef<HTMLDivElement>(null)
  const [open, setOpen] = useState(false)
  useClickOutside(ref, open, () => setOpen(false))

  const items: Item[] = [
    ...(showResolve
      ? [
          {
            value: 'resolved' as const,
            label: t('CONVERSATION.HEADER.RESOLVE_ACTION'),
            icon: 'ph-check',
          },
        ]
      : []),
    ...(showReopen
      ? [
          {
            value: 'open' as const,
            label: t('CONVERSATION.HEADER.REOPEN_ACTION'),
            icon: 'ph-arrow-clockwise',
          },
        ]
      : []),
    ...(showSnooze
      ? [
          {
            value: 'snoozed' as const,
            label: t('BULK_ACTION.UPDATE.SNOOZE_UNTIL'),
            icon: 'ph-alarm',
          },
        ]
      : []),
  ]

  return (
    <div ref={ref} className="relative">
      <Button
        icon="ph-arrow-circle-up"
        color="slate"
        size="xs"
        variant="ghost"
        title={t('BULK_ACTION.UPDATE.CHANGE_STATUS')}
        aria-label={t('BULK_ACTION.UPDATE.CHANGE_STATUS')}
        className={open ? 'bg-n-alpha-2' : undefined}
        onClick={() => setOpen((o) => !o)}
      />
      <DropdownMenu
        id="bulk-update-actions"
        open={open}
        items={items}
        showSearch={false}
        searchPlaceholder=""
        emptyState=""
        // No Chatwoot o snooze abre o submenu da command bar (Cmd+K), que ainda não existe: só visual.
        isDisabled={(item) => item.value === 'snoozed'}
        renderItem={(item) => <Icon name={item.icon} className="flex-shrink-0 size-3.5" />}
        className="-right-[4.5rem] 2xl:right-0 bottom-8 w-36"
        onSelect={(value) => {
          onUpdate(value)
          setOpen(false)
        }}
      />
    </div>
  )
}
