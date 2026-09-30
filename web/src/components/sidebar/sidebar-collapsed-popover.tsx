// Port de sidebar/SidebarCollapsedPopover.vue; a posição vem do usePopoverState.
import { useState } from 'react'

import { ChannelIcon } from '../next/channel-icon'
import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { SidebarLink } from './link-context'
import type { ActivePopover } from './use-popover-state'
import {
  isSubgroup,
  visibleChildren,
  type MenuGroup,
  type MenuLeaf,
  type MenuSubgroup,
} from './sidebar-menu'

type Props = {
  group: MenuGroup
  activeLeaf: string | null
  popover: ActivePopover | null
  onEnter: () => void
  onLeave: () => void
  onNavigate: () => void
}

function PopoverItem({
  leaf,
  active,
  onNavigate,
}: {
  leaf: MenuLeaf
  active: boolean
  onNavigate: () => void
}) {
  const classes = cx(
    'flex items-center gap-2 px-2 py-1.5 w-full rounded-lg text-sm text-left transition-colors duration-150 ease-out',
    active ? 'text-n-slate-12 bg-n-alpha-2' : 'text-n-slate-11 hover:bg-n-alpha-2',
  )
  const content = (
    <>
      {leaf.channel ? (
        <ChannelIcon channel={leaf.channel} className="size-4 flex-shrink-0" />
      ) : (
        leaf.icon && <Icon name={leaf.icon} className="size-4 flex-shrink-0" />
      )}
      <span className="flex-1 truncate">{leaf.label}</span>
    </>
  )
  return leaf.to ? (
    <SidebarLink
      to={leaf.to}
      aria-current={active ? 'page' : undefined}
      onClick={onNavigate}
      className={classes}
    >
      {content}
    </SidebarLink>
  ) : (
    // sem rota ainda: só visual
    <div className={classes}>{content}</div>
  )
}

function PopoverSection({
  section,
  activeLeaf,
  onNavigate,
}: {
  section: MenuSubgroup
  activeLeaf: string | null
  onNavigate: () => void
}) {
  const [open, setOpen] = useState(section.children.some((leaf) => leaf.name === activeLeaf))
  const toggle = () => setOpen((value) => !value)
  return (
    <li
      id={`sidebar-popover-section-${section.name}`}
      data-open={String(open)}
      className="group/popsection py-0.5"
    >
      <div className="flex items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 transition-colors duration-150 ease-out">
        <button
          type="button"
          onClick={toggle}
          className="flex flex-1 min-w-0 items-center gap-2 ps-2 py-1.5 text-left"
        >
          {section.icon && <Icon name={section.icon} className="size-4 flex-shrink-0" />}
          <span className="flex-1 truncate text-sm">{section.label}</span>
        </button>
        <div className="flex flex-shrink-0 items-center gap-1 pe-2">
          <button
            type="button"
            aria-label={section.label}
            aria-expanded={open}
            onClick={toggle}
            className="flex size-6 flex-shrink-0 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 focus-visible:outline-none"
          >
            <Icon
              name="ph-caret-down"
              className="size-4 flex-shrink-0 transition-transform group-data-[open=true]/popsection:rotate-180"
            />
          </button>
        </div>
      </div>
      <ul className="m-0 p-0 list-none pl-4 mt-1 overflow-hidden hidden group-data-[open=true]/popsection:block">
        {section.children.map((leaf) => (
          <li key={leaf.name} className="py-0.5">
            <PopoverItem leaf={leaf} active={leaf.name === activeLeaf} onNavigate={onNavigate} />
          </li>
        ))}
      </ul>
    </li>
  )
}

export function SidebarCollapsedPopover({
  group,
  activeLeaf,
  popover,
  onEnter,
  onLeave,
  onNavigate,
}: Props) {
  const open = popover?.name === group.name
  return (
    <div
      id={`sidebar-popover-${group.name}`}
      data-popover={group.name}
      hidden={!open}
      style={open ? { top: popover.top, left: popover.left } : undefined}
      onMouseEnter={onEnter}
      onMouseLeave={onLeave}
      className="absolute z-[100] min-w-[200px] max-w-[280px]"
    >
      <div className="bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 -outline-offset-1 w-56 outline-n-weak rounded-xl shadow-lg py-2 px-2">
        <div className="px-2 py-1.5 text-xs font-medium text-n-slate-11 uppercase tracking-wider border-b border-n-weak mb-1">
          {group.label}
        </div>
        <ul className="m-0 p-0 list-none max-h-[400px] overflow-y-auto no-scrollbar">
          {visibleChildren(group).map((child) =>
            isSubgroup(child) ? (
              <PopoverSection
                key={child.name}
                section={child}
                activeLeaf={activeLeaf}
                onNavigate={onNavigate}
              />
            ) : (
              <li key={child.name} className="py-0.5">
                <PopoverItem
                  leaf={child}
                  active={child.name === activeLeaf}
                  onNavigate={onNavigate}
                />
              </li>
            ),
          )}
        </ul>
      </div>
    </div>
  )
}
