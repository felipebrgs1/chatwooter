// Port de components-next/CardLayout.vue.
import type { ReactNode } from 'react'

import { cx } from './cx'

type Props = {
  layout?: 'col' | 'row'
  selectable?: boolean
  className?: string
  children: ReactNode
  /** Slot `after`: conteúdo abaixo da linha principal (ex.: formulário expandido). */
  after?: ReactNode
}

export function CardLayout({
  layout = 'col',
  selectable = false,
  className,
  children,
  after,
}: Props) {
  return (
    <div
      className={cx(
        'group/cardLayout flex w-full flex-col rounded-xl bg-n-solid-2 outline outline-1 -outline-offset-1 outline-n-container',
        className,
      )}
    >
      <div
        className={cx(
          'flex w-full gap-3 py-5',
          layout === 'col' ? 'flex-col' : 'flex-row items-center justify-between',
          selectable ? 'px-10 py-6' : 'px-6',
        )}
      >
        {children}
      </div>
      {after}
    </div>
  )
}
