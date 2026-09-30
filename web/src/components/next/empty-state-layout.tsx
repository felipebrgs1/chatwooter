// Port de components-next/EmptyStateLayout.vue: prévia esmaecida ao fundo, título e ações por cima.
import type { ReactNode } from 'react'

import { cx } from './cx'

type Props = {
  title: string
  subtitle: string
  showBackdrop?: boolean
  /** Slot `empty-state-item`: a prévia (cards de exemplo) atrás do texto. */
  backdrop?: ReactNode
  actions?: ReactNode
  className?: string
}

export function EmptyStateLayout({
  title,
  subtitle,
  showBackdrop = true,
  backdrop,
  actions,
  className,
}: Props) {
  return (
    <section
      className={cx(
        'relative flex h-full w-full flex-col items-center justify-center overflow-hidden',
        className,
      )}
    >
      <div className="relative mx-auto h-full max-h-[28rem] w-full max-w-5xl overflow-hidden">
        {showBackdrop && (
          <div
            aria-hidden="true"
            className="pointer-events-none h-full w-full space-y-4 overflow-y-hidden opacity-50"
          >
            {backdrop}
          </div>
        )}
        <div
          className={cx(
            'flex h-full w-full flex-col items-center justify-end pb-20',
            showBackdrop &&
              'absolute inset-x-0 bottom-0 bg-gradient-to-t from-n-surface-1 from-25% to-transparent',
          )}
        >
          <div
            className={cx(
              'flex flex-col items-center justify-center gap-6',
              !showBackdrop && 'mt-48',
            )}
          >
            <div className="flex flex-col items-center justify-center gap-3">
              <h2 className="text-center text-3xl font-medium text-n-slate-12">{title}</h2>
              {subtitle && (
                <p className="max-w-xl text-center text-base tracking-[0.3px] text-n-slate-11">
                  {subtitle}
                </p>
              )}
            </div>
            {actions}
          </div>
        </div>
      </div>
    </section>
  )
}
