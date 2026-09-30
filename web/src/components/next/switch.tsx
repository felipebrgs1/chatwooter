// Port de components-next/switch/Switch.vue.
import { cx } from './cx'

type Props = {
  id: string
  checked?: boolean
  onChange?: (checked: boolean) => void
  /** Texto para leitores de tela (o original usa "Toggle"). */
  label: string
  disabled?: boolean
}

export function Switch({ id, checked = false, onChange, label, disabled }: Props) {
  return (
    <button
      id={id}
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange?.(!checked)}
      className={cx(
        'group relative h-4 rounded-full w-7 flex-shrink-0 select-none focus:outline-none focus:ring-1 focus:ring-n-brand focus:ring-offset-n-slate-2 focus:ring-offset-2 transition-colors duration-200 ease-in-out',
        checked ? 'bg-n-brand' : 'bg-n-slate-6',
      )}
    >
      <span className="sr-only">{label}</span>
      <span
        className={cx(
          'absolute top-1/2 left-0.5 -translate-y-1/2 transition-transform duration-[350ms] ease-[cubic-bezier(0.34,1.56,0.64,1)]',
          checked ? 'translate-x-3 group-active:translate-x-[6px]' : 'translate-x-0',
        )}
      >
        <span className="block h-3 w-3 rounded-full bg-n-background shadow-md transition-[width] duration-[180ms] ease-in-out group-active:w-[18px]" />
      </span>
    </button>
  )
}
