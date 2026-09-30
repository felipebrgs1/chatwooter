// Port de sidebar/SidebarGroup.vue (expandida) + SidebarGroupHeader.vue.
import { useState } from 'react'

import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { SidebarLink } from './link-context'
import { SidebarLeaf } from './sidebar-leaf'
import { SidebarSubgroup } from './sidebar-subgroup'
import { isSubgroup, leavesOf, visibleChildren, type MenuGroup } from './sidebar-menu'

type Props = {
  group: MenuGroup
  activeLeaf: string | null
  accountId: number
  minimizedSections: Record<string, boolean>
  onToggleSection: (key: string) => void
}

function HeaderContent({ group, activeChild }: { group: MenuGroup; activeChild: boolean }) {
  return (
    <>
      <div className="relative flex items-center gap-2">
        <Icon name={group.icon} className="size-4" />
      </div>
      <div className="flex items-center gap-1.5 flex-grow justify-between min-w-0 flex-1">
        <span
          className={cx('truncate text-start text-body-main', activeChild && 'font-medium text-sm')}
        >
          {group.label}
        </span>
      </div>
    </>
  )
}

export function SidebarGroup({
  group,
  activeLeaf,
  accountId,
  minimizedSections,
  onToggleSection,
}: Props) {
  const leaves = leavesOf(group)
  const activeChild = leaves.some((leaf) => leaf.name === activeLeaf)
  const firstLeaf = leaves[0]
  const visible = visibleChildren(group)
  const lastVisible = visible.at(-1)

  const [expanded, setExpanded] = useState(activeChild)
  // Navegar para dentro do grupo o expande (ajuste durante a renderização, sem efeito)
  const [wasActive, setWasActive] = useState(activeChild)
  if (wasActive !== activeChild) {
    setWasActive(activeChild)
    if (activeChild) setExpanded(true)
  }
  const toggle = () => setExpanded((open) => !open)

  // No grupo ativo o clique só expande/recolhe; nos demais navega para o primeiro filho
  // (SidebarGroup.toggleTrigger). Sem rota no primeiro filho, o cabeçalho só expande.
  const buttonHeader = activeChild || !firstLeaf?.to

  return (
    <li
      id={`sidebar-group-${group.name}`}
      data-expanded={String(expanded)}
      className="group/nav grid gap-1 text-sm cursor-pointer select-none min-w-0"
    >
      {buttonHeader ? (
        <button
          type="button"
          title={group.label}
          onClick={toggle}
          className={cx(
            'flex items-center gap-2 px-1.5 py-1 rounded-lg h-8 min-w-0',
            activeChild ? 'text-n-slate-12 font-medium' : 'text-n-slate-11 hover:bg-n-alpha-2',
          )}
        >
          <HeaderContent group={group} activeChild={activeChild} />
          {activeChild && (
            <Icon
              name="ph-caret-up"
              className="size-3 hidden group-data-[expanded=true]/nav:inline-block"
            />
          )}
        </button>
      ) : (
        <SidebarLink
          to={firstLeaf.to!}
          title={group.label}
          draggable={false}
          className="flex items-center gap-2 px-1.5 py-1 rounded-lg h-8 min-w-0 text-n-slate-11 hover:bg-n-alpha-2"
        >
          <HeaderContent group={group} activeChild={activeChild} />
        </SidebarLink>
      )}
      <ul
        className={cx(
          'm-0 list-none min-w-0',
          expanded || activeChild ? 'grid' : 'hidden group-data-[expanded=true]/nav:grid',
        )}
      >
        {visible.map((child) => {
          if (!isSubgroup(child)) {
            return <SidebarLeaf key={child.name} leaf={child} active={child.name === activeLeaf} />
          }
          const key = `${accountId}:${group.name}:${child.name}`
          const hasActive = child.children.some((leaf) => leaf.name === activeLeaf)
          return (
            <SidebarSubgroup
              key={child.name}
              subgroup={child}
              endTreeLine={Boolean(child.treeLine) && child === lastVisible}
              activeLeaf={activeLeaf}
              // Seção com o item ativo sempre abre (SidebarSubGroup.expandSubGroupOnActiveChild)
              minimized={Boolean(minimizedSections[key]) && !hasActive}
              onToggle={() => onToggleSection(key)}
            />
          )
        })}
      </ul>
    </li>
  )
}
