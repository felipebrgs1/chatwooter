// Port de sidebar/SidebarProfileMenu.vue.
import { useTranslation } from 'react-i18next'

import type { Availability } from '../../api/types'
import { Avatar } from '../next/avatar'
import { cx } from '../next/cx'
import { DropdownContainer } from '../next/dropdown-container'
import { Icon } from '../next/icon'
import { Switch } from '../next/switch'
import { AvailabilitySelect } from './availability-select'

type Props = {
  name: string
  email: string
  availability: Availability
  autoOffline: boolean
  collapsed: boolean
  onAvailabilityChange: (availability: Availability) => void
  onAutoOfflineChange: (autoOffline: boolean) => void
  onSignOut: () => void
}

const itemClasses =
  'flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 hover:bg-n-alpha-2 rounded-lg gap-3'

export function ProfileMenu({
  name,
  email,
  availability,
  autoOffline,
  collapsed,
  onAvailabilityChange,
  onAutoOfflineChange,
  onSignOut,
}: Props) {
  const { t } = useTranslation()

  return (
    <div className={cx('min-w-0', collapsed ? 'w-auto' : 'w-full')}>
      <DropdownContainer
        id="sidebar-profile-menu"
        trigger={({ toggle }) => (
          <button
            id="sidebar-profile-menu-trigger"
            type="button"
            title={collapsed ? name : undefined}
            onClick={toggle}
            className={cx(
              'flex gap-2 items-center p-1 text-left rounded-lg cursor-pointer hover:bg-n-alpha-1',
              collapsed ? 'justify-center' : 'w-full',
            )}
          >
            <Avatar name={name} size={32} status={availability} />
            {!collapsed && (
              <div className="min-w-0">
                <div className="text-sm font-medium leading-4 truncate text-n-slate-12">{name}</div>
                <div className="text-xs truncate text-n-slate-11">{email}</div>
              </div>
            )}
          </button>
        )}
      >
        {({ close }) => (
          <div className="absolute bottom-12 z-50 mb-2 w-80 left-0">
            <ul className="text-sm bg-n-alpha-3 backdrop-blur-[100px] border rounded-xl shadow-sm py-2 gap-2 grid list-none px-2 relative border-n-weak">
              <li className="-mx-2">
                <ul className="gap-2 grid list-none px-2 max-h-96 overflow-visible">
                  <li>
                    <div className="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 gap-1">
                      <div className="flex-grow flex items-center gap-1 min-w-0">
                        {t('SIDEBAR.SET_YOUR_AVAILABILITY')}
                      </div>
                      <div className="shrink-0">
                        <AvailabilitySelect value={availability} onChange={onAvailabilityChange} />
                      </div>
                    </div>
                  </li>
                  <li>
                    <div className="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0">
                      <div className="flex-grow min-w-0">
                        {t('SIDEBAR.SET_AUTO_OFFLINE.TEXT')}
                        <span
                          title={t('SIDEBAR.SET_AUTO_OFFLINE.INFO_SHORT')}
                          className="inline-block align-middle ms-1"
                        >
                          <Icon name="ph-info" className="size-4 text-n-slate-10" />
                        </span>
                      </div>
                      <Switch
                        id="sidebar-auto-offline"
                        checked={autoOffline}
                        label={t('SWITCH.TOGGLE')}
                        onChange={onAutoOfflineChange}
                      />
                    </div>
                  </li>
                </ul>
              </li>
              <li className="h-0 border-b border-n-strong -mx-2" />
              <li>
                {/* sem rota ainda: Profile settings aparece só visual */}
                <div className={cx(itemClasses, 'cursor-default')}>
                  <Icon name="ph-user-gear" className="size-4 text-n-slate-11" />
                  {t('SIDEBAR_ITEMS.PROFILE_SETTINGS')}
                </div>
              </li>
              <li>
                <button
                  type="button"
                  onClick={() => {
                    close()
                    onSignOut()
                  }}
                  className={cx(itemClasses, 'cursor-pointer')}
                >
                  <Icon name="ph-power" className="size-4 text-n-slate-11" />
                  {t('SIDEBAR_ITEMS.LOGOUT')}
                </button>
              </li>
            </ul>
          </div>
        )}
      </DropdownContainer>
    </div>
  )
}
