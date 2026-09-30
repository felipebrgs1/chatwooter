// Port de components-next/label/AddLabel.vue: botão "+ tag" que abre a lista de etiquetas com busca.
import { useEffect, useId, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { cx } from './cx'
import { DropdownMenu } from './dropdown-menu'
import { Icon } from './icon'

export type LabelMenuItem = { value: number; label: string; color: string }

type Props = {
  items: LabelMenuItem[]
  selected: number[]
  onSelect: (id: number) => void
}

export function AddLabel({ items, selected, onSelect }: Props) {
  const { t } = useTranslation()
  const id = useId()
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onClick = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('click', onClick)
    return () => document.removeEventListener('click', onClick)
  }, [open])

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        aria-expanded={open}
        className={cx(
          'flex h-6 items-center gap-1 rounded-md px-2 py-1 outline-dashed outline-1 outline-n-slate-6 hover:bg-n-alpha-2',
          open && 'bg-n-alpha-2',
        )}
        onClick={() => setOpen((o) => !o)}
      >
        <Icon name="ph-plus" />
        <span className="text-sm text-n-slate-11">{t('LABEL.TAG_BUTTON')}</span>
      </button>
      <DropdownMenu
        id={id}
        open={open}
        // os já escolhidos vão para o fim (toSorted por isSelected), marcados
        items={[...items].sort(
          (a, b) => Number(selected.includes(a.value)) - Number(selected.includes(b.value)),
        )}
        selected={null}
        searchPlaceholder={t('DROPDOWN_MENU.SEARCH_PLACEHOLDER')}
        emptyState={t('DROPDOWN_MENU.EMPTY_STATE')}
        className="top-full z-[100] mt-2 max-h-52 w-48 ltr:left-0 rtl:right-0"
        renderItem={(item) => (
          <>
            <div className="size-2 rounded-sm" style={{ backgroundColor: item.color }} />
            {selected.includes(item.value) && (
              <Icon name="ph-check" className="size-3.5 text-n-slate-11" />
            )}
          </>
        )}
        onSelect={(value) => {
          onSelect(Number(value))
          setOpen(false)
        }}
      />
    </div>
  )
}
