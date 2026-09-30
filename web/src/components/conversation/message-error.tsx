// Porta de components-next/message/MessageError.vue.
import { useTranslation } from 'react-i18next'

import { cx } from '../next/cx'
import { Icon } from '../next/icon'

type Props = {
  error: string
  orientation: 'left' | 'right'
  /** Só dá para reenviar dentro de um dia e se houver o que reenviar */
  canRetry: boolean
  onRetry?: () => void
  className?: string
}

export function MessageError({ error, orientation, canRetry, onRetry, className }: Props) {
  const { t } = useTranslation()
  return (
    <div className={cx('flex items-center gap-1.5 text-xs text-n-ruby-11', className)}>
      <span>{t('CHAT_LIST.FAILED_TO_SEND')}</span>
      <div className="group relative">
        <div className="grid size-5 cursor-pointer place-content-center rounded-md bg-n-alpha-2">
          <Icon name="ph-warning" className="size-[14px] text-n-ruby-11" />
        </div>
        <div
          className={cx(
            'invisible absolute bottom-6 w-52 break-all rounded-xl border border-n-strong bg-n-alpha-3 px-4 py-3 text-xs text-n-slate-12 opacity-0 shadow-[0px_0px_24px_0px_rgba(0,0,0,0.12)] backdrop-blur-[100px] transition-all group-hover:visible group-hover:opacity-100',
            orientation === 'left' ? 'left-0' : 'right-0',
          )}
        >
          {error}
        </div>
      </div>
      {canRetry && (
        <button
          type="button"
          aria-label={t('DATA_IMPORTS.TABLE.RETRY')}
          onClick={onRetry}
          className="grid size-5 cursor-pointer place-content-center rounded-md bg-n-alpha-2"
        >
          <Icon name="ph-arrow-clockwise" className="size-[14px] text-n-ruby-11" />
        </button>
      )}
    </div>
  )
}
