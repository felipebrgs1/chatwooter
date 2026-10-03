// Port de components/widgets/conversation/conversationBulkActions/BulkLabelActions.vue (só o tipo conversa).
import { useQuery } from '@tanstack/react-query'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { labelsQuery } from '../../../api/labels'
import { useAccountId } from '../../../api/use-account-id'
import { Button } from '../../next/button'
import { DropdownMenu } from '../../next/dropdown-menu'
import { Icon } from '../../next/icon'
import { useClickOutside } from '../../next/use-click-outside'

type Props = {
  action?: 'assign' | 'remove'
  /** Na remoção, só as etiquetas já aplicadas em alguma selecionada. */
  appliedLabels?: string[]
  onApply: (labels: string[]) => void
}

export function BulkLabelActions({ action = 'assign', appliedLabels, onApply }: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const { data: labels = [] } = useQuery(labelsQuery(accountId))
  const ref = useRef<HTMLDivElement>(null)
  const [open, setOpen] = useState(false)
  const [selected, setSelected] = useState<string[]>([])
  const isRemove = action === 'remove'

  const dismiss = () => {
    setSelected([])
    setOpen(false)
  }
  useClickOutside(ref, open, dismiss)

  const visible =
    isRemove && appliedLabels ? labels.filter((l) => appliedLabels.includes(l.title)) : labels
  const items = visible.map((label) => ({
    value: label.title,
    label: label.title,
    color: label.color,
  }))
  const toggle = (title: string) =>
    setSelected((current) =>
      current.includes(title) ? current.filter((l) => l !== title) : [...current, title],
    )

  const tooltip = t(
    isRemove ? 'BULK_ACTION.LABELS.REMOVE_LABELS' : 'BULK_ACTION.LABELS.ASSIGN_LABELS',
  )

  return (
    <div ref={ref} className="relative">
      <Button
        // Phosphor não tem a etiqueta com "menos" (i-woot-tag-remove): a remoção usa tag-simple
        icon={isRemove ? 'ph-tag-simple' : 'ph-tag'}
        color="slate"
        size="xs"
        variant="ghost"
        title={tooltip}
        aria-label={tooltip}
        className={open ? 'bg-n-alpha-2' : undefined}
        onClick={() => setOpen((o) => !o)}
      />
      <DropdownMenu
        id={`bulk-label-${action}`}
        open={open}
        items={items}
        onSelect={(value) => toggle(String(value))}
        isSelected={(item) => selected.includes(item.value)}
        searchPlaceholder={t('BULK_ACTION.SEARCH_INPUT_PLACEHOLDER')}
        emptyState={t('DROPDOWN_MENU.EMPTY_STATE')}
        className="w-60 max-h-80 -right-[6.5rem] 2xl:right-0 bottom-8"
        renderItem={(item) => (
          <span
            className="rounded-md h-3 w-3 flex-shrink-0 border border-solid border-n-weak"
            style={{ backgroundColor: item.color }}
          />
        )}
        renderTrailing={(item) =>
          selected.includes(item.value) && (
            <Icon name="ph-check" className="size-4 text-n-blue-11 flex-shrink-0" />
          )
        }
        footer={
          <div className="sticky bottom-0 rounded-b-md px-2 py-2 z-20 bg-n-alpha-3 backdrop-blur-[4px]">
            <Button
              size="sm"
              className="w-full"
              label={t(
                isRemove
                  ? 'BULK_ACTION.LABELS.REMOVE_SELECTED_LABELS'
                  : 'BULK_ACTION.LABELS.ASSIGN_SELECTED_LABELS',
              )}
              disabled={selected.length === 0}
              onClick={() => {
                if (!selected.length) return
                onApply(selected)
                dismiss()
              }}
            />
          </div>
        }
      />
    </div>
  )
}
