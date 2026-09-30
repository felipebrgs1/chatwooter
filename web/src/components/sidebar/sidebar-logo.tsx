// Logo do topo da sidebar (SidebarAccountSwitcher.vue): círculo de marca com o ícone de chat.
import { cx } from '../next/cx'
import { Icon } from '../next/icon'

type Props = { className?: string; iconClassName?: string }

export function SidebarLogo({ className = 'size-4', iconClassName = 'size-2.5' }: Props) {
  return (
    <span className={cx('grid place-content-center rounded-full bg-n-brand', className)}>
      <Icon name="ph-chat-circle" className={cx('text-white', iconClassName)} />
    </span>
  )
}
