// Port de components/widgets/conversation/conversationBulkActions/BulkTeamActions.vue.
import { useQuery } from '@tanstack/react-query'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { teamsQuery } from '../../../api/teams'
import { useAccountId } from '../../../api/use-account-id'
import { Button } from '../../next/button'
import { DropdownMenu } from '../../next/dropdown-menu'
import { useClickOutside } from '../../next/use-click-outside'
import { BulkAssignConfirm } from './bulk-assign-confirm'

/** id 0 = "None" (tira o time). */
export type BulkTeam = { id: number; name: string }

type Props = {
  conversationCount: number
  onSelect: (team: BulkTeam) => void
}

const NONE = 'none'

export function BulkTeamActions({ conversationCount, onSelect }: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const { data: teams = [] } = useQuery(teamsQuery(accountId))
  const ref = useRef<HTMLDivElement>(null)
  const [open, setOpen] = useState(false)
  const [selected, setSelected] = useState<BulkTeam | null>(null)

  const dismiss = () => {
    setSelected(null)
    setOpen(false)
  }
  useClickOutside(ref, open, dismiss)

  const none = t('BULK_ACTION.TEAMS.NONE')
  const items = [
    { value: NONE as string | number, label: none },
    ...teams.map((team) => ({ value: team.id, label: team.name })),
  ]

  return (
    <div ref={ref} className="relative">
      <Button
        icon="ph-users"
        color="slate"
        size="xs"
        variant="ghost"
        title={t('BULK_ACTION.ASSIGN_TEAM_TOOLTIP')}
        aria-label={t('BULK_ACTION.ASSIGN_TEAM_TOOLTIP')}
        className={open ? 'bg-n-alpha-2' : undefined}
        onClick={() => setOpen((o) => !o)}
      />
      <DropdownMenu
        id="bulk-team-actions"
        open={open}
        items={items}
        selected={selected ? selected.id || NONE : null}
        searchPlaceholder={t('BULK_ACTION.SEARCH_INPUT_PLACEHOLDER')}
        emptyState={t('DROPDOWN_MENU.EMPTY_STATE')}
        className="-right-2 bottom-8 w-60 max-h-80"
        onSelect={(value) => {
          const team = teams.find((tm) => tm.id === value)
          setSelected(team ? { id: team.id, name: team.name } : { id: 0, name: none })
        }}
        footer={
          selected && (
            <BulkAssignConfirm
              keypath={
                selected.id
                  ? 'BULK_ACTION.TEAMS.ASSIGN_TEAM_CONFIRMATION_LABEL'
                  : 'BULK_ACTION.TEAMS.UNASSIGN_TEAM_CONFIRMATION_LABEL'
              }
              count={conversationCount}
              nameKey={selected.id ? 'teamName' : undefined}
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
