// Port de sidebar/SidebarProfileMenuStatus.vue (seletor de disponibilidade).
import { useTranslation } from 'react-i18next'

import type { Availability } from '../../api/types'
import { cx } from '../next/cx'
import { DropdownContainer } from '../next/dropdown-container'
import { Icon } from '../next/icon'

const statuses: { value: Availability; key: string; color: string }[] = [
  { value: 'online', key: 'ONLINE', color: 'bg-n-teal-9' },
  { value: 'busy', key: 'BUSY', color: 'bg-n-amber-9' },
  { value: 'offline', key: 'OFFLINE', color: 'bg-n-slate-9' },
]

type Props = { value: Availability; onChange: (value: Availability) => void }

export function AvailabilitySelect({ value, onChange }: Props) {
  const { t } = useTranslation()
  const label = (key: string) => t(`PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.${key}`)
  const active = statuses.find((s) => s.value === value) ?? statuses[2]

  return (
    <DropdownContainer
      id="sidebar-availability-menu"
      trigger={({ toggle }) => (
        <button
          id="sidebar-availability-menu-trigger"
          type="button"
          onClick={toggle}
          className="inline-flex items-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline bg-n-slate-9/10 text-n-slate-12 hover:enabled:bg-n-slate-9/20 focus-visible:bg-n-slate-9/20 outline-transparent h-8 px-3 text-sm active:enabled:scale-[0.97]"
        >
          <div className="flex gap-1 items-center min-w-0 text-sm">
            <div className="p-1 flex-shrink-0">
              <div className={cx('size-2 rounded-sm', active.color)} />
            </div>
            <span className="truncate max-w-[7rem]">{label(active.key)}</span>
          </div>
          <Icon name="ph-caret-down" className="size-4 flex-shrink-0" />
        </button>
      )}
    >
      {({ close }) => (
        <div className="absolute min-w-32 z-20">
          <ul className="text-sm bg-n-alpha-3 backdrop-blur-[100px] border rounded-xl shadow-sm py-2 gap-2 grid list-none px-2 relative border-n-weak">
            {statuses.map((status) => (
              <li key={status.value}>
                <button
                  id={`sidebar-availability-${status.value}`}
                  type="button"
                  onClick={() => {
                    close()
                    onChange(status.value)
                  }}
                  className="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 hover:bg-n-alpha-2 rounded-lg gap-3 cursor-pointer"
                >
                  <span className={cx(status.color, 'size-[12px] rounded')} />
                  {label(status.key)}
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </DropdownContainer>
  )
}
