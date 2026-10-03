// O #footer de confirmação do BulkAgentActions.vue e do BulkTeamActions.vue.
import { useTranslation } from 'react-i18next'

import { Button } from '../../next/button'
import { I18nT } from '../../next/i18n-t'

type Props = {
  /** Chave com {n} e o nome (assign) ou só {n} (unassign). */
  keypath: string
  count: number
  nameKey?: string
  name?: string
  onCancel: () => void
  onConfirm: () => void
}

export function BulkAssignConfirm({ keypath, count, nameKey, name, onCancel, onConfirm }: Props) {
  const { t } = useTranslation()
  return (
    <div className="pt-2 pb-2 px-2 border-t border-n-weak sticky bottom-0 rounded-b-md z-20 bg-n-alpha-3 backdrop-blur-[4px]">
      <div className="flex flex-col gap-2">
        <I18nT
          keypath={keypath}
          plural={count}
          className="text-xs text-n-slate-11 px-1 mb-0"
          values={{
            n: <strong className="text-n-slate-12">{count}</strong>,
            ...(nameKey ? { [nameKey]: <strong className="text-n-slate-12">{name}</strong> } : {}),
          }}
        />
        <div className="flex gap-2">
          <Button
            size="sm"
            variant="faded"
            color="slate"
            className="flex-1"
            label={t('BULK_ACTION.CANCEL')}
            onClick={onCancel}
          />
          <Button size="sm" className="flex-1" label={t('BULK_ACTION.YES')} onClick={onConfirm} />
        </div>
      </div>
    </div>
  )
}
