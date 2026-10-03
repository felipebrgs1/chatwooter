// Port de components/widgets/conversation/conversationBulkActions/BulkAgentActions.vue.
import { useQuery } from '@tanstack/react-query'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { assignableAgentsQuery } from '../../../api/agents'
import { useAccountId } from '../../../api/use-account-id'
import { Avatar } from '../../next/avatar'
import { Button } from '../../next/button'
import { DropdownMenu } from '../../next/dropdown-menu'
import { useClickOutside } from '../../next/use-click-outside'
import { BulkAssignConfirm } from './bulk-assign-confirm'

export type BulkAgent = { id: number | null; name: string }

type Props = {
  selectedInboxes: number[]
  conversationCount: number
  onSelect: (agent: BulkAgent) => void
}

const NONE = 'none'

export function BulkAgentActions({ selectedInboxes, conversationCount, onSelect }: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const ref = useRef<HTMLDivElement>(null)
  const [open, setOpen] = useState(false)
  const [selected, setSelected] = useState<BulkAgent | null>(null)
  // só busca ao abrir, para as inboxes da seleção
  const { data: agents = [], isFetching } = useQuery({
    ...assignableAgentsQuery(accountId, selectedInboxes),
    enabled: open && selectedInboxes.length > 0,
  })

  const dismiss = () => {
    setSelected(null)
    setOpen(false)
  }
  useClickOutside(ref, open, dismiss)

  const none = t('BULK_ACTION.NONE')
  const items = [
    { value: NONE as string | number, label: none, thumbnail: '' },
    ...agents.map((agent) => ({ value: agent.id, label: agent.name, thumbnail: agent.thumbnail })),
  ]

  return (
    <div ref={ref} className="relative">
      <Button
        icon="ph-user-check"
        color="slate"
        size="xs"
        variant="ghost"
        title={t('BULK_ACTION.ASSIGN_AGENT_TOOLTIP')}
        aria-label={t('BULK_ACTION.ASSIGN_AGENT_TOOLTIP')}
        className={open ? 'bg-n-alpha-2' : undefined}
        onClick={() => setOpen((o) => !o)}
      />
      <DropdownMenu
        id="bulk-agent-actions"
        open={open}
        items={items}
        isLoading={isFetching}
        selected={selected ? (selected.id ?? NONE) : null}
        searchPlaceholder={t('BULK_ACTION.SEARCH_INPUT_PLACEHOLDER')}
        emptyState={t('DROPDOWN_MENU.EMPTY_STATE')}
        className="-right-10 2xl:right-0 bottom-8 w-60 max-h-80"
        renderItem={(item) => (
          <span aria-hidden="true">
            <Avatar name={item.label} src={item.thumbnail} size={20} />
          </span>
        )}
        onSelect={(value) =>
          setSelected(
            value === NONE
              ? { id: null, name: none }
              : (agents.find((a) => a.id === value) ?? { id: null, name: none }),
          )
        }
        footer={
          selected && (
            <BulkAssignConfirm
              keypath={
                selected.id
                  ? 'BULK_ACTION.ASSIGN_AGENT_CONFIRMATION_LABEL'
                  : 'BULK_ACTION.UNASSIGN_AGENT_CONFIRMATION_LABEL'
              }
              count={conversationCount}
              nameKey={selected.id ? 'agentName' : undefined}
              name={selected.name}
              onCancel={() => setSelected(null)}
              onConfirm={() => {
                onSelect(selected)
                dismiss()
              }}
            />
          )
        }
      />
    </div>
  )
}
