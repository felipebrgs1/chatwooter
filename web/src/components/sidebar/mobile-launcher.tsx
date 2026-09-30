// Port de sidebar/MobileSidebarLauncher.vue.
import { useTranslation } from 'react-i18next'

import { Icon } from '../next/icon'

export function MobileLauncher({ onToggle }: { onToggle: () => void }) {
  const { t } = useTranslation()
  return (
    <div
      id="mobile-sidebar-launcher"
      className="fixed bottom-4 left-4 z-40 transition-transform duration-200 ease-out block md:hidden peer-data-[mobile-open=true]:translate-x-48"
    >
      <div className="inline-flex rounded-full bg-n-alpha-2 backdrop-blur-lg p-1 shadow hover:shadow-md">
        <button
          type="button"
          aria-label={t('KEYBOARD_SHORTCUTS.TITLE.TOGGLE_SIDEBAR')}
          onClick={onToggle}
          className="inline-flex items-center justify-center min-w-0 border-0 outline-1 outline outline-transparent size-10 p-0 rounded-full bg-n-solid-3 dark:bg-n-alpha-2 text-n-slate-12 text-xl transition-all duration-200 ease-out hover:brightness-110"
        >
          <Icon name="ph-list" className="size-5" />
        </button>
      </div>
    </div>
  )
}
