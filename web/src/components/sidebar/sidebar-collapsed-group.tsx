// Port de sidebar/SidebarGroup.vue, ramo isCollapsed: só o ícone; os filhos vão no popover.
import type { MouseEvent } from 'react'

import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { SidebarLink } from './link-context'
import { leavesOf, type MenuGroup } from './sidebar-menu'

type Props = {
  group: MenuGroup
  activeLeaf: string | null
  onHover: (event: MouseEvent<HTMLElement>) => void
  onLeave: () => void
}

export function SidebarCollapsedGroup({ group, activeLeaf, onHover, onLeave }: Props) {
  const leaves = leavesOf(group)
  const activeChild = leaves.some((leaf) => leaf.name === activeLeaf)
  const firstLeaf = leaves[0]
  const classes = cx(
    'flex items-center justify-center size-10 rounded-lg',
    activeChild ? 'text-n-slate-12 bg-n-alpha-2' : 'text-n-slate-11 hover:bg-n-alpha-2',
  )
  const icon = <Icon name={group.icon} className="size-4" />

  return (
    <li
      id={`sidebar-group-${group.name}`}
      className="grid gap-1 text-sm cursor-pointer select-none min-w-0"
    >
      {firstLeaf?.to ? (
        <SidebarLink
          to={firstLeaf.to}
          data-popover-trigger={group.name}
          title={group.label}
          onMouseEnter={onHover}
          onMouseLeave={onLeave}
          className={classes}
        >
          {icon}
        </SidebarLink>
      ) : (
        // sem rota ainda: o ícone só abre o popover
        <div
          data-popover-trigger={group.name}
          title={group.label}
          onMouseEnter={onHover}
          onMouseLeave={onLeave}
          className={classes}
        >
          {icon}
        </div>
      )}
    </li>
  )
}
