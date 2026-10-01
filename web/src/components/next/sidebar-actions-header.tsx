// Port de components-next/SidebarActionsHeader.vue: título do painel lateral e o botão de fechar.
import { useTranslation } from 'react-i18next'

import { Button } from './button'

type Props = { title: string; onClose: () => void }

export function SidebarActionsHeader({ title, onClose }: Props) {
  const { t } = useTranslation()
  return (
    <div className="flex items-center justify-between px-4 py-2 border-b border-n-weak h-12">
      <div className="flex items-center justify-between gap-2 flex-1">
        <span className="font-medium text-sm text-n-slate-12">{title}</span>
        <div className="flex items-center">
          <Button
            icon="ph-x"
            variant="ghost"
            size="sm"
            title={t('GENERAL.CLOSE')}
            aria-label={t('GENERAL.CLOSE')}
            onClick={onClose}
          />
        </div>
      </div>
    </div>
  )
}
