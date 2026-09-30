// Port de conversationCardComponents/CardLabels.vue: cada etiqueta é um woot-label (variante smooth, pequena).
// As que não cabem numa linha ficam escondidas e o chevron mostra todas.
import { useLayoutEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { cx } from '../next/cx'
import { Icon } from '../next/icon'

export interface AccountLabel {
  title: string
  color: string
  description?: string | null
}

type Props = {
  labels: string[]
  accountLabels?: AccountLabel[]
  /** CardLabelsV5 `disable-toggle`: o card expandido não mostra o chevron. */
  disableToggle?: boolean
  className?: string
}

export function CardLabels({ labels, accountLabels = [], disableToggle, className }: Props) {
  const { t } = useTranslation()
  const row = useRef<HTMLDivElement>(null)
  const [showAll, setShowAll] = useState(false)
  const [overflowing, setOverflowing] = useState(false)

  useLayoutEffect(() => {
    const el = row.current
    if (!el) return
    const measure = () => setOverflowing(el.scrollHeight > el.clientHeight + 1 || showAll)
    measure()
    if (typeof ResizeObserver === 'undefined') return
    const observer = new ResizeObserver(measure)
    observer.observe(el)
    return () => observer.disconnect()
  }, [labels, showAll])

  if (labels.length === 0) return null

  return (
    <div className={cx('flex', className)}>
      <div
        ref={row}
        className={cx(
          'flex min-w-0 flex-wrap items-end gap-y-1',
          !showAll && 'max-h-5 overflow-hidden',
        )}
      >
        {labels.map((title) => {
          const known = accountLabels.find((l) => l.title === title)
          return (
            <div
              key={title}
              title={known?.description ?? undefined}
              className="label smooth small mb-0 me-1 inline-flex h-5 max-w-[calc(100%-0.5rem)] items-center gap-1 rounded-[4px] border border-solid border-n-strong bg-transparent px-1 py-0.5 text-xs font-medium leading-tight text-n-slate-11 dark:text-n-slate-12"
            >
              {known && (
                <span
                  className="inline-block h-2 w-2 flex-shrink-0 rounded-sm shadow-sm"
                  style={{ background: known.color }}
                />
              )}
              <span className="overflow-hidden text-ellipsis whitespace-nowrap">{title}</span>
            </div>
          )
        })}
      </div>
      {!disableToggle && overflowing && labels.length > 1 && (
        <button
          type="button"
          title={showAll ? t('CONVERSATION.CARD.HIDE_LABELS') : t('CONVERSATION.CARD.SHOW_LABELS')}
          aria-label={
            showAll ? t('CONVERSATION.CARD.HIDE_LABELS') : t('CONVERSATION.CARD.SHOW_LABELS')
          }
          onClick={(event) => {
            // o botão fica dentro do link do card: clicar nele não abre a conversa
            event.preventDefault()
            event.stopPropagation()
            setShowAll((v) => !v)
          }}
          className="me-6 ms-0 h-5 flex-shrink-0 border-n-strong px-1 py-0 text-n-slate-11"
        >
          <Icon name={showAll ? 'ph-caret-left' : 'ph-caret-right'} className="size-3" />
        </button>
      )}
    </div>
  )
}
