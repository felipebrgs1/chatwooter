// Port de components-next/Conversation/SidepanelSwitch.vue: abre/fecha o painel do contato (Alt+O).
// O botão do Copilot (Captain, enterprise) não entra.
import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'

import { useUiSettings } from '../../../api/use-ui-settings'
import { useAltShortcut } from '../../../shared/use-alt-shortcut'
import { Button } from '../../next/button'
import { cx } from '../../next/cx'

export function SidepanelSwitch() {
  const { t } = useTranslation()
  const { uiSettings, update } = useUiSettings()
  const isOpen = !!uiSettings.is_contact_sidebar_open
  const toggle = useCallback(
    () => void update({ is_contact_sidebar_open: !isOpen, is_copilot_panel_open: false }),
    [update, isOpen],
  )
  useAltShortcut('KeyO', toggle)

  return (
    <div className="flex flex-col justify-center items-center absolute top-36 xl:top-24 ltr:right-2 rtl:left-2 bg-n-solid-2/90 backdrop-blur-lg border border-n-weak/50 rounded-full gap-1.5 p-1.5 shadow-sm transition-shadow duration-200 hover:shadow !z-20">
      <Button
        variant="ghost"
        color="slate"
        size="sm"
        icon="ph-user-bold"
        title={t('CONVERSATION.SIDEBAR.CONTACT')}
        aria-label={t('CONVERSATION.SIDEBAR.CONTACT')}
        aria-pressed={isOpen}
        className={cx(
          '!rounded-full transition-all duration-[250ms] ease-out active:!scale-95 active:!brightness-105 active:duration-75',
          isOpen && 'bg-n-alpha-2 active:shadow-sm',
        )}
        onClick={toggle}
      />
    </div>
  )
}
