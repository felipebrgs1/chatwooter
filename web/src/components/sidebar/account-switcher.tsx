// Port de sidebar/SidebarAccountSwitcher.vue: lista as contas do perfil e troca pela escolhida.
import { useTranslation } from 'react-i18next'

import type { ProfileAccount } from '../../api/types'
import { cx } from '../next/cx'
import { DropdownContainer } from '../next/dropdown-container'
import { Icon } from '../next/icon'
import { SidebarLogo } from './sidebar-logo'

type Props = {
  accounts: ProfileAccount[]
  currentAccountId: number
  collapsed: boolean
  onSwitch: (accountId: number) => void
}

export function AccountSwitcher({ accounts, currentAccountId, collapsed, onSwitch }: Props) {
  const { t } = useTranslation()
  const currentName = accounts.find((a) => a.id === currentAccountId)?.name ?? ''
  const title = t('SIDEBAR_ITEMS.SWITCH_ACCOUNT')

  return (
    <DropdownContainer
      id="sidebar-account-menu"
      trigger={({ toggle }) =>
        collapsed ? (
          // recolhida: o logo abre a lista de contas
          <button
            id="sidebar-account-menu-trigger"
            type="button"
            title={currentName}
            onClick={toggle}
            className="grid flex-shrink-0 place-content-center p-2 rounded-lg cursor-pointer hover:bg-n-alpha-1"
          >
            <SidebarLogo className="size-7" iconClassName="size-4" />
          </button>
        ) : (
          <button
            id="sidebar-account-menu-trigger"
            type="button"
            onClick={toggle}
            className="flex items-center gap-2 justify-between w-full rounded-lg px-2 cursor-pointer flex-grow -mx-1 min-w-0 hover:bg-n-alpha-1"
          >
            <span
              className="text-sm font-medium leading-5 text-n-slate-12 truncate"
              aria-live="polite"
            >
              {currentName}
            </span>
            <Icon name="ph-caret-down" className="size-3 flex-shrink-0 text-n-slate-10" />
          </button>
        )
      }
    >
      {({ close }) => (
        <div className="absolute min-w-80 z-50">
          <div className="text-sm bg-n-alpha-3 backdrop-blur-[100px] border rounded-xl shadow-sm py-2 gap-2 grid px-2 relative border-n-weak">
            <div className="-mx-2">
              <div className="px-4 mb-3 mt-1 leading-4 font-medium tracking-[0.2px] text-n-slate-10 text-xs">
                {title}
              </div>
              <ul aria-label={title} className="gap-2 grid list-none px-2 overflow-y-auto max-h-96">
                {accounts.map((account) => {
                  const current = account.id === currentAccountId
                  return (
                    <li key={account.id} id={`account-${account.id}`}>
                      <button
                        type="button"
                        aria-current={current ? 'true' : undefined}
                        onClick={() => {
                          close()
                          if (!current) onSwitch(account.id)
                        }}
                        className={cx(
                          'flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 hover:bg-n-alpha-2 rounded-lg gap-3 cursor-pointer',
                        )}
                      >
                        <div className="text-left flex gap-2 items-center">
                          <span
                            className="text-n-slate-12 max-w-36 truncate min-w-0"
                            title={account.name}
                          >
                            {account.name}
                          </span>
                          <div className="flex-shrink-0 w-px h-3 bg-n-strong" />
                          <span className="text-n-slate-11 max-w-24 truncate capitalize">
                            {account.role}
                          </span>
                        </div>
                        {current && <Icon name="ph-check" className="text-n-teal-11 size-5" />}
                      </button>
                    </li>
                  )
                })}
              </ul>
            </div>
          </div>
        </div>
      )}
    </DropdownContainer>
  )
}
