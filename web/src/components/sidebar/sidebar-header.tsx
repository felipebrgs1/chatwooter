// Topo da sidebar (Sidebar.vue): conta, busca e nova conversa.
import { useTranslation } from 'react-i18next'

import type { ProfileAccount } from '../../api/types'
import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { AccountSwitcher } from './account-switcher'
import { SidebarLogo } from './sidebar-logo'

type Props = {
  accounts: ProfileAccount[]
  currentAccountId: number
  collapsed: boolean
  onSwitchAccount: (accountId: number) => void
  onCompose?: () => void
}

export function SidebarHeader({
  accounts,
  currentAccountId,
  collapsed,
  onSwitchAccount,
  onCompose,
}: Props) {
  const { t } = useTranslation()
  const switcher = (
    <AccountSwitcher
      accounts={accounts}
      currentAccountId={currentAccountId}
      collapsed={collapsed}
      onSwitch={onSwitchAccount}
    />
  )
  const searchLabel = t('COMBOBOX.SEARCH_PLACEHOLDER')

  return (
    <section className={cx('grid', collapsed ? 'mt-3 mb-6 gap-4' : 'mt-1 mb-4 gap-2')}>
      <div
        className={cx(
          'flex gap-2 items-center min-w-0',
          collapsed ? 'justify-center px-1' : 'px-2',
        )}
      >
        {collapsed ? (
          switcher
        ) : (
          <>
            <div className="grid flex-shrink-0 place-content-center size-6">
              <SidebarLogo />
            </div>
            <div className="flex-shrink-0 w-px h-3 bg-n-strong" />
            {switcher}
          </>
        )}
      </div>
      <div className={cx('flex gap-2', collapsed ? 'flex-col items-center' : 'px-2')}>
        {/* sem rota ainda: a busca (/app/search) aparece só visual */}
        {collapsed ? (
          <div
            id="sidebar-search"
            title={searchLabel}
            className="flex items-center justify-center size-8 rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-all duration-100 ease-out hover:bg-n-alpha-2 dark:hover:bg-n-slate-9/30"
          >
            <Icon name="ph-magnifying-glass" className="size-4 text-n-slate-11" />
          </div>
        ) : (
          <div
            id="sidebar-search"
            className="flex gap-2 items-center px-2 py-1 w-full h-7 rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-all duration-100 ease-out"
          >
            <Icon name="ph-magnifying-glass" className="flex-shrink-0 size-4 text-n-slate-10" />
            <span className="flex-grow text-start text-n-slate-10">{searchLabel}</span>
          </div>
        )}
        <button
          id="sidebar-compose"
          type="button"
          title={t('NEW_CONVERSATION.TITLE')}
          onClick={onCompose}
          className={cx(
            'inline-flex items-center justify-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline bg-n-button-color hover:enabled:bg-n-alpha-2 dark:hover:enabled:bg-n-slate-9/30 p-0 text-sm active:enabled:scale-[0.97] outline-n-weak text-n-slate-11 shrink-0',
            collapsed ? 'size-8' : 'w-8 h-7',
          )}
        >
          <Icon name="ph-note-pencil" className="size-4" />
        </button>
      </div>
    </section>
  )
}
