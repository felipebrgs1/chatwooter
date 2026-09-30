// Port de components-next/checkbox/Checkbox.vue. Só desenha: vive dentro de links (card de conversa),
// onde um <input> real brigaria com a navegação; o pai trata o clique e atualiza `checked`.
import type { HTMLAttributes } from 'react'

import { cx } from './cx'

type Props = Omit<HTMLAttributes<HTMLSpanElement>, 'role'> & {
  checked?: boolean
  indeterminate?: boolean
}

const mark =
  'pointer-events-none absolute w-3.5 h-3.5 stroke-white left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2'

export function Checkbox({ checked = false, indeterminate = false, className, ...rest }: Props) {
  return (
    <span
      role="checkbox"
      aria-checked={indeterminate ? 'mixed' : checked}
      className={cx('relative block w-4 h-4 flex-shrink-0', className)}
      {...rest}
    >
      <span
        className={cx(
          'absolute inset-0 h-4 w-4 rounded border transition-all duration-200 cursor-pointer',
          checked || indeterminate
            ? 'border-n-brand bg-n-brand'
            : 'border-n-slate-6 hover:bg-n-blue-border',
        )}
      />
      {checked && !indeterminate && (
        <svg viewBox="0 0 14 14" fill="none" className={mark}>
          <path d="M3 8L6 11L11 3.5" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      )}
      {indeterminate && (
        <svg viewBox="0 0 14 14" fill="none" className={mark}>
          <path d="M3 7L11 7" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      )}
    </span>
  )
}
