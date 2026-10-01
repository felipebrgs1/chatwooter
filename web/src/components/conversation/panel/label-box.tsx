// Port de routes/dashboard/conversation/labels/LabelBox.vue + shared/components/ui/label/LabelDropdown.vue
// (+ LabelDropdownItem.vue, dropdown/AddLabel.vue e o woot-label "smooth"): etiquetas da conversa.
// Sugestões do Captain (enterprise) e "Create new label" (sem tela de etiquetas ainda) não entram.
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import type { Label } from '../../../api/types'
import { Button } from '../../next/button'
import { Icon } from '../../next/icon'
import { useAltShortcut } from '../../../shared/use-alt-shortcut'

type Props = {
  /** Títulos salvos na conversa, na ordem em que foram aplicados. */
  savedLabels: string[]
  accountLabels: Label[]
  onAdd: (title: string) => void
  onRemove: (title: string) => void
}

export function LabelBox({ savedLabels, accountLabels, onAdd, onRemove }: Props) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const ref = useRef<HTMLDivElement>(null)
  const activeLabels = savedLabels
    .map((title) => accountLabels.find((label) => label.title === title))
    .filter((label): label is Label => !!label)
  const filtered = search
    ? accountLabels.filter((label) => label.title.toLowerCase().includes(search.toLowerCase()))
    : accountLabels

  const close = () => {
    setOpen(false)
    setSearch('')
  }
  // o original usa a tecla L sozinha (useKeyboardEvents KeyL); aqui os atalhos do app são com Alt
  useAltShortcut('KeyL', () => setOpen((o) => !o))

  useEffect(() => {
    if (!open) return
    const onPointerDown = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) close()
    }
    document.addEventListener('mousedown', onPointerDown)
    return () => document.removeEventListener('mousedown', onPointerDown)
  }, [open])

  return (
    <div className="mb-0 w-full">
      <div
        ref={ref}
        className="relative flex flex-wrap leading-6"
        onKeyUp={(e) => e.key === 'Escape' && close()}
      >
        <Button
          variant="faded"
          size="xs"
          icon="ph-plus"
          className="mb-0.5 ltr:mr-0.5 rtl:ml-0.5 !rounded-[4px]"
          label={t('CONTACT_PANEL.LABELS.CONVERSATION.ADD_BUTTON')}
          onClick={() => (open ? close() : setOpen(true))}
        />
        {activeLabels.map((label) => (
          <div
            key={label.id}
            title={label.description || label.title}
            className="inline-flex ltr:mr-1 rtl:ml-1 mb-1 items-center font-medium text-xs rounded-[4px] gap-1 p-1 bg-transparent text-n-slate-11 dark:text-n-slate-12 border border-solid border-n-strong h-6 max-w-[calc(100%-0.5rem)]"
          >
            {/* cor da etiqueta vem do banco (labels.color) */}
            <span
              className="inline-block w-3 h-3 rounded-sm shadow-sm flex-shrink-0"
              style={{ background: label.color }}
            />
            <span className="whitespace-nowrap text-ellipsis overflow-hidden">{label.title}</span>
            <button
              type="button"
              aria-label={`${t('CONVERSATION.ASSIGNMENT.REMOVE')} ${label.title}`}
              className="text-n-slate-11 -mb-0.5 rounded-sm cursor-pointer flex items-center justify-center hover:bg-n-slate-3 p-0"
              onClick={() => onRemove(label.title)}
            >
              <Icon name="ph-x" className="size-3 text-n-slate-11" />
            </button>
          </div>
        ))}
        {open && (
          <div className="border rounded-lg bg-n-alpha-3 top-6 backdrop-blur-[100px] absolute w-full shadow-lg border-n-strong dark:border-n-strong p-2 box-border z-[9999]">
            <div className="flex flex-col w-full max-h-[12.5rem]">
              <div className="flex items-center justify-center mb-1">
                <h4 className="flex-grow m-0 overflow-hidden text-sm text-n-slate-12 whitespace-nowrap text-ellipsis">
                  {t('CONTACT_PANEL.LABELS.LABEL_SELECT.TITLE')}
                </h4>
              </div>
              <div className="flex-auto flex-grow-0 flex-shrink-0 mb-2 max-h-8">
                <input
                  autoFocus
                  type="text"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder={t('CONTACT_PANEL.LABELS.LABEL_SELECT.PLACEHOLDER')}
                  className="m-0 w-full border border-solid border-transparent h-8 text-sm text-n-slate-12 rounded-md focus:border-n-brand bg-n-background px-2"
                />
              </div>
              <div className="flex items-start justify-start flex-auto flex-grow flex-shrink overflow-auto">
                <div className="w-full my-1">
                  <ul className="list-none m-0 p-0 flex flex-col gap-1">
                    {filtered.map((label) => {
                      const selected = savedLabels.includes(label.title)
                      return (
                        <li key={label.title}>
                          <Button
                            color="slate"
                            variant="ghost"
                            trailingIcon
                            icon={selected ? 'ph-check-circle' : undefined}
                            className="w-full !px-2.5 justify-between"
                            onClick={() => (selected ? onRemove(label.title) : onAdd(label.title))}
                          >
                            <div className="flex items-center min-w-0 gap-2">
                              <div
                                className="size-3 flex-shrink-0 rounded-full outline outline-1 outline-n-weak"
                                style={{ backgroundColor: label.color }}
                              />
                              <span
                                className="overflow-hidden text-ellipsis whitespace-nowrap leading-[1.1]"
                                title={label.title}
                              >
                                {label.title}
                              </span>
                            </div>
                          </Button>
                        </li>
                      )
                    })}
                  </ul>
                  {filtered.length === 0 && (
                    <div className="flex justify-center py-4 px-2.5 font-medium text-xs text-n-slate-11">
                      {t('CONTACT_PANEL.LABELS.LABEL_SELECT.NO_RESULT')}
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
