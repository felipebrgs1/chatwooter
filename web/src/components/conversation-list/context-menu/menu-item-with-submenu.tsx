// Port de components/widgets/conversation/contextMenu/menuItemWithSubmenu.vue. O submenu aparece no :hover
// (CSS, como no original) e se posiciona, ao entrar o mouse, para não sair da janela.
import { useRef, useState, type ReactNode } from 'react'

import { cx } from '../../next/cx'
import { Icon } from '../../next/icon'
import type { MenuOption } from './menu-item'

const SUBMENU_HEIGHT = 240 // 15rem
const SUBMENU_WIDTH = 240

type Props = {
  option: MenuOption
  subMenuAvailable?: boolean
  children: ReactNode
}

export function MenuItemWithSubmenu({ option, subMenuAvailable = true, children }: Props) {
  const ref = useRef<HTMLDivElement>(null)
  const [placement, setPlacement] = useState(['top-0', 'left-full'])

  const place = () => {
    const rect = ref.current?.getBoundingClientRect()
    if (!rect) return
    setPlacement([
      window.innerHeight - rect.bottom < SUBMENU_HEIGHT ? 'bottom-0' : 'top-0',
      window.innerWidth - rect.right < SUBMENU_WIDTH ? 'right-full' : 'left-full',
    ])
  }

  return (
    <div
      ref={ref}
      role="button"
      aria-label={option.label}
      aria-haspopup="menu"
      aria-disabled={!subMenuAvailable || undefined}
      className={cx(
        'group/submenu relative flex h-7 w-full min-w-[12.5rem] cursor-pointer items-center justify-between rounded-md bg-n-alpha-3/50 p-1 text-n-slate-12 backdrop-blur-[100px] hover:bg-n-brand/10 dark:hover:bg-n-solid-3',
        !subMenuAvailable && 'cursor-not-allowed opacity-50',
      )}
      onMouseEnter={place}
    >
      <div className="flex h-4 items-center">
        {option.icon && <Icon name={option.icon} className="size-3.5" />}
        <p className="mx-2 my-0 text-xs">{option.label}</p>
      </div>
      <Icon name="ph-caret-right" className="size-3" />
      {subMenuAvailable && (
        <div
          role="menu"
          className={cx(
            'absolute hidden group-hover/submenu:block max-h-[15rem] cursor-pointer overflow-y-auto overflow-x-hidden rounded-md bg-n-alpha-3 p-1 shadow-lg backdrop-blur-[100px]',
            ...placement,
          )}
        >
          {children}
        </div>
      )}
    </div>
  )
}
