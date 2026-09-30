// Port da moldura de components-next/Editor/Editor.vue. O WootEditor (ProseMirror, barra de formatação) ainda
// não existe aqui: o texto vai num textarea e o markdown é interpretado na exibição, como no composer.
import { useState, type ReactNode } from 'react'

import { cx } from './cx'

type Props = {
  value: string
  onChange: (value: string) => void
  placeholder?: string
  label?: string
  disabled?: boolean
  focusOnMount?: boolean
  /** Slot `actions`: botões no rodapé, à direita. */
  actions?: ReactNode
  className?: string
  onKeyDown?: (event: React.KeyboardEvent<HTMLTextAreaElement>) => void
}

export function Editor({
  value,
  onChange,
  placeholder,
  label,
  disabled = false,
  focusOnMount = false,
  actions,
  className,
  onKeyDown,
}: Props) {
  const [focused, setFocused] = useState(false)
  return (
    <div className={cx('flex min-w-0 flex-col gap-1', className)}>
      {label && <label className="mb-0.5 text-sm font-medium text-n-slate-12">{label}</label>}
      <div
        className={cx(
          'editor-wrapper flex w-full flex-col gap-2 rounded-lg border bg-n-alpha-black2 px-3 py-3 transition-all duration-500 ease-in-out',
          disabled && 'pointer-events-none cursor-not-allowed opacity-50',
          focused ? 'border-n-brand' : 'border-n-weak hover:border-n-slate-6',
        )}
      >
        <textarea
          value={value}
          placeholder={placeholder}
          aria-label={placeholder}
          disabled={disabled}
          autoFocus={focusOnMount}
          rows={3}
          className="w-full resize-none bg-transparent text-sm text-n-slate-12 outline-none placeholder:text-n-slate-11"
          onChange={(event) => onChange(event.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          onKeyDown={onKeyDown}
        />
        {actions && <div className="flex h-4 items-center justify-end">{actions}</div>}
      </div>
    </div>
  )
}
