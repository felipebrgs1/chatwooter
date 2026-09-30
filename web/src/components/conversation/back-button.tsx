// Port de components/widgets/BackButton.vue: volta à lista de conversas mantendo os filtros da URL.
import { useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { cx } from '../next/cx'
import { Icon } from '../next/icon'

export function BackButton({ className }: { className?: string }) {
  const { t } = useTranslation()
  const navigate = useNavigate()

  return (
    <button
      type="button"
      onClick={() => void navigate({ to: '/app', search: true })}
      className={cx(
        'flex cursor-pointer items-center p-0 text-base font-normal text-n-slate-11',
        className,
      )}
    >
      <Icon name="ph-caret-left" className="-ml-1 text-lg" />
      {t('GENERAL_SETTINGS.BACK')}
    </button>
  )
}
