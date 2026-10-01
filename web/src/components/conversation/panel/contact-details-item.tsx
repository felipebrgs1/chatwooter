// Port de routes/dashboard/conversation/ContactDetailsItem.vue: título de um campo do painel + ação opcional.
import type { ReactNode } from 'react'

import { cx } from '../../next/cx'

type Props = { title: string; compact?: boolean; button?: ReactNode }

export function ContactDetailsItem({ title, compact = false, button }: Props) {
  return (
    <div className={cx('overflow-auto', compact ? 'py-0 px-0' : 'py-3 px-4')}>
      <div className="items-center flex justify-between mb-1.5">
        <span className="text-sm font-medium text-n-slate-12">{title}</span>
        {button}
      </div>
    </div>
  )
}
