// Porta de components-next/message/bubbles/Base.vue (cores por variante, cantos por orientação, meta).
import type { ReactNode } from 'react'

import { cx } from '../next/cx'
import type { DeliveryStatus } from './delivery-status'
import { MessageMeta } from './message-meta'
import type { Orientation, Variant } from './message-variant'

const variantClasses: Record<Variant, string> = {
  agent: 'bg-n-solid-blue text-n-slate-12',
  private: 'bg-n-solid-amber text-n-amber-12',
  user: 'bg-n-slate-4 text-n-slate-12',
  activity: 'bg-n-alpha-1 text-n-slate-11 text-sm',
  bot: 'bg-n-solid-iris text-n-slate-12',
  template: 'bg-n-solid-iris text-n-slate-12',
  error: 'bg-n-ruby-4 text-n-ruby-12',
}

const orientationClasses: Record<Orientation, string> = {
  left: 'left-bubble rounded-xl rounded-bl-sm',
  right: 'right-bubble rounded-xl rounded-br-sm',
  center: 'rounded-md',
}

const justify: Record<Orientation, string> = {
  left: 'justify-start',
  right: 'justify-end',
  center: 'justify-center',
}

type Props = {
  variant: Variant
  orientation: Orientation
  createdAt: number
  status: DeliveryStatus | null
  /** Agrupada com a próxima: sem meta */
  groupWithNext?: boolean
  /** A anterior está agrupada com esta: canto superior reto */
  continuesGroup?: boolean
  /** Identifica o tipo do balão (text, image, ...) */
  name: string
  className?: string
  hideMeta?: boolean
  children: ReactNode
}

export function Bubble({
  variant,
  orientation,
  createdAt,
  status,
  groupWithNext = false,
  continuesGroup = false,
  name,
  className,
  hideMeta = false,
  children,
}: Props) {
  const showMeta = !hideMeta && !groupWithNext && variant !== 'activity'
  return (
    <div
      data-variant={variant}
      data-bubble-name={name}
      className={cx(
        'min-w-0 max-w-lg text-sm',
        variantClasses[variant],
        variant === 'activity' ? 'rounded-lg' : orientationClasses[orientation],
        continuesGroup && (orientation === 'left' ? 'rounded-tl-sm' : 'rounded-tr-sm'),
        className,
      )}
    >
      {children}
      {showMeta && (
        <div
          className={cx(
            'mt-2 flex',
            justify[orientation],
            variant === 'private' ? 'text-n-amber-12/50' : 'text-n-slate-11',
          )}
        >
          <MessageMeta createdAt={createdAt} isPrivate={variant === 'private'} status={status} />
        </div>
      )}
    </div>
  )
}
