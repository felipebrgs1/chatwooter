// Port de components/widgets/conversation/conversationBulkActions/Index.vue: a barra que aparece com
// conversas selecionadas. O snooze (command bar e CustomSnoozeModal) ainda não existe.
import { useTranslation } from 'react-i18next'

import type { ConversationStatus } from '../../../api/types'
import { Button } from '../../next/button'
import { Checkbox } from '../../next/checkbox'
import { cx } from '../../next/cx'
import { BulkAgentActions, type BulkAgent } from './bulk-agent-actions'
import { BulkLabelActions } from './bulk-label-actions'
import { BulkTeamActions, type BulkTeam } from './bulk-team-actions'
import { BulkUpdateActions } from './bulk-update-actions'

type Props = {
  count: number
  allConversationsSelected: boolean
  selectedInboxes: number[]
  appliedLabels: string[]
  showOpenAction: boolean
  showResolvedAction: boolean
  showSnoozedAction: boolean
  className?: string
  onSelectAll: (checked: boolean) => void
  onAssignLabels: (labels: string[]) => void
  onRemoveLabels: (labels: string[]) => void
  onUpdate: (status: ConversationStatus) => void
  onAssignAgent: (agent: BulkAgent) => void
  onAssignTeam: (team: BulkTeam) => void
}

export function ConversationBulkActions(props: Props) {
  const { t } = useTranslation()
  if (props.count === 0) return null
  const selectedLabel = t('BULK_ACTION.CONVERSATIONS_SELECTED', {
    conversationCount: props.count,
  })

  return (
    <div
      className={cx(
        'px-2 absolute bottom-20 sm:bottom-4 left-1/2 -translate-x-1/2 z-30 w-full origin-bottom',
        props.className,
      )}
    >
      {props.allConversationsSelected && (
        <div className="bg-n-amber-2 outline -outline-offset-1 outline-1 outline-n-amber-5 rounded-lg text-sm mb-2 py-1.5 px-2 text-n-amber-text">
          {t('BULK_ACTION.ALL_CONVERSATIONS_SELECTED_ALERT')}
        </div>
      )}
      <div className="flex items-center justify-between gap-2 p-2 bg-n-button-color outline outline-1 -outline-offset-1 rounded-[10px] outline-n-weak shadow-[0_0_12px_0_rgba(27,40,59,0.08)]">
        <div className="ms-0.5 flex items-center gap-1 min-w-0">
          <label
            className="cursor-pointer flex items-center gap-1.5 min-w-0"
            onClick={(event) => {
              event.preventDefault()
              props.onSelectAll(!props.allConversationsSelected)
            }}
          >
            <Checkbox
              checked={props.allConversationsSelected}
              indeterminate={!props.allConversationsSelected}
              aria-label={selectedLabel}
              className="flex-shrink-0"
            />
            <span title={selectedLabel} className="cursor-pointer truncate">
              {selectedLabel}
            </span>
          </label>
          <div className="w-px h-3 bg-n-weak rounded-lg ms-1 flex-shrink-0" />
          <Button
            label={t('BULK_ACTION.CLEAR_SELECTION')}
            variant="ghost"
            size="sm"
            className="!text-n-blue-11 !px-1 !h-6 flex-shrink-0"
            onClick={() => props.onSelectAll(false)}
          />
        </div>
        <div className="flex items-center gap-2 flex-shrink-0">
          <BulkLabelActions onApply={props.onAssignLabels} />
          <BulkLabelActions
            action="remove"
            appliedLabels={props.appliedLabels}
            onApply={props.onRemoveLabels}
          />
          <BulkUpdateActions
            showResolve={!props.showResolvedAction}
            showReopen={!props.showOpenAction}
            showSnooze={!props.showSnoozedAction}
            onUpdate={props.onUpdate}
          />
          <BulkAgentActions
            selectedInboxes={props.selectedInboxes}
            conversationCount={props.count}
            onSelect={props.onAssignAgent}
          />
          <BulkTeamActions conversationCount={props.count} onSelect={props.onAssignTeam} />
        </div>
      </div>
    </div>
  )
}
