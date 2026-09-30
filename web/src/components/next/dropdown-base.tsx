// Port de components-next/dropdown-menu/base/{DropdownBody,DropdownSection,DropdownItem}.vue:
// as peças do corpo de um DropdownContainer.
import type { ReactNode } from 'react'

import { cx } from './cx'
import { Icon } from './icon'

type BodyProps = {
  /** Dropdown dentro de outro: borda forte e a camada extra de blur (o Chrome não empilha backdrop-blur). */
  strong?: boolean
  className?: string
  children: ReactNode
}

export function DropdownBody({ strong = false, className, children }: BodyProps) {
  return (
    <div className={cx('absolute', className)}>
      <ul
        className={cx(
          'text-sm bg-n-alpha-3 backdrop-blur-[100px] border rounded-xl shadow-sm py-2 gap-2 grid list-none px-2 relative',
          strong ? 'border-n-strong' : 'border-n-weak',
          strong &&
            "before:content-['\\00A0'] before:absolute before:bottom-0 before:left-0 before:w-full before:h-full before:rounded-xl before:backdrop-contrast-70 before:backdrop-blur-sm before:z-0 [&>*]:relative",
        )}
      >
        {children}
      </ul>
    </div>
  )
}

export function DropdownSection({
  title,
  height = 'max-h-96',
  className,
  children,
}: {
  title?: string
  height?: string
  className?: string
  children: ReactNode
}) {
  return (
    <div className={cx('-mx-2', className)}>
      {title && (
        <div className="px-4 mb-3 mt-1 leading-4 font-medium tracking-[0.2px] text-n-slate-10 text-xs">
          {title}
        </div>
      )}
      <ul className={cx('gap-2 grid list-none px-2 overflow-y-auto', height)}>{children}</ul>
    </div>
  )
}

type ItemProps = {
  label?: ReactNode
  icon?: string
  /** Substitui o ícone padrão (bolinha de cor, emoji...). */
  iconSlot?: ReactNode
  onClick?: () => void
  disabled?: boolean
  children?: ReactNode
}

export function DropdownItem({ label, icon, iconSlot, onClick, disabled, children }: ItemProps) {
  const classes = cx(
    'flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0',
    !children && 'hover:bg-n-alpha-2 rounded-lg w-full gap-3',
  )
  const content = children ?? (
    <>
      {iconSlot ?? (icon && <Icon name={icon} className="size-4 text-n-slate-11" />)}
      {label}
    </>
  )
  return (
    <li>
      {onClick && !disabled ? (
        <button type="button" className={cx(classes, 'cursor-pointer')} onClick={onClick}>
          {content}
        </button>
      ) : (
        <div className={classes}>{content}</div>
      )}
    </li>
  )
}
