// Port de components-next/label/LabelItem.vue: etiqueta com cor e botão de remover que aparece no hover.
import { Button } from './button'
import { cx } from './cx'

export type LabelItemData = { id: number; title: string; color: string }

type Props = {
  label: LabelItemData
  isHovered: boolean
  onHover: (id: number) => void
  onRemove: (label: LabelItemData) => void
}

export function LabelItem({ label, isHovered, onHover, onRemove }: Props) {
  return (
    <div
      className="flex h-7 items-center overflow-hidden rounded-md bg-n-alpha-2 px-1 py-1 transition-all duration-300 ease-out"
      onMouseEnter={() => onHover(label.id)}
    >
      <div className="m-1 h-2 w-2 rounded-sm" style={{ backgroundColor: label.color }} />
      <span className="text-sm text-n-slate-12 ltr:mr-px rtl:ml-px">{label.title}</span>
      <div
        className={cx(
          'relative flex w-0 flex-shrink-0 overflow-hidden transition-[width] duration-300 ease-out ltr:left-1 rtl:right-1',
          isHovered && 'w-6',
        )}
      >
        <Button
          type="button"
          color="slate"
          size="xs"
          variant="faded"
          icon="ph-x"
          className={cx(
            '!h-7 w-6 bg-transparent transition-opacity duration-200 ltr:rounded-l-none ltr:rounded-r-md rtl:rounded-l-md rtl:rounded-r-none',
            isHovered ? 'opacity-100' : 'opacity-0',
          )}
          onClick={() => onRemove(label)}
        />
      </div>
    </div>
  )
}
