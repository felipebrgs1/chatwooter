// Porta de components/buttons/ResolveAction.vue (só Resolve / Reopen / Open; snooze e pending ficam fora desta fatia).
import { useTranslation } from 'react-i18next'

import type { ConversationStatus } from '../../api/types'
import { Button } from '../next/button'

type Props = {
  status: ConversationStatus
  isLoading?: boolean
  onChange: (status: ConversationStatus) => void
}

export function ResolveAction({ status, isLoading = false, onChange }: Props) {
  const { t } = useTranslation()
  const [label, next]: [string, ConversationStatus] =
    status === 'open'
      ? [t('CONVERSATION.HEADER.RESOLVE_ACTION'), 'resolved']
      : status === 'resolved'
        ? [t('CONVERSATION.HEADER.REOPEN_ACTION'), 'open']
        : [t('CONVERSATION.HEADER.OPEN_ACTION'), 'open']

  return (
    <div className="resolve-actions relative flex items-center justify-end">
      <div className="flex-shrink-0 rounded-lg shadow outline outline-1 outline-n-container">
        <Button
          label={label}
          size="sm"
          color="slate"
          noAnimation
          disabled={isLoading}
          className="!outline-0"
          onClick={() => onChange(next)}
        />
      </div>
    </div>
  )
}
