// Port de sidebar/SidebarSubGroup.vue + SidebarGroupSeparator.vue. Recolher é estado do pai (persistido lá).
import { useState, type UIEvent } from 'react'

import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { SidebarLeaf } from './sidebar-leaf'
import type { MenuSubgroup } from './sidebar-menu'
import { childrenTrunk, treeElbow, treeVerticalLine } from './tree-classes'

// Subgrupos com mais itens que isso viram lista rolável (SidebarSubGroup.isScrollable)
const SCROLL_THRESHOLD = 7

type Props = {
  subgroup: MenuSubgroup
  endTreeLine: boolean
  activeLeaf: string | null
  minimized: boolean
  onToggle: () => void
}

export function SidebarSubgroup({ subgroup, endTreeLine, activeLeaf, minimized, onToggle }: Props) {
  const [scrollEnd, setScrollEnd] = useState(false)
  const { collapsible, treeLine } = subgroup
  const scrollable = subgroup.children.length > SCROLL_THRESHOLD

  const onScroll = (event: UIEvent<HTMLDivElement>) => {
    const { scrollHeight, scrollTop, clientHeight } = event.currentTarget
    setScrollEnd(Math.abs(scrollHeight - scrollTop - clientHeight) < 1)
  }

  return (
    <li
      id={`sidebar-section-${subgroup.name}`}
      data-minimized={String(minimized)}
      data-scroll-end={String(scrollEnd)}
      className="group/section relative flex flex-col list-none min-w-0"
    >
      <div
        className={cx(
          'relative min-w-0 my-1 hidden group-data-[expanded=true]/nav:block',
          collapsible && 'ms-5',
        )}
      >
        <div
          title={subgroup.label}
          onClick={collapsible ? onToggle : undefined}
          className={cx(
            'relative flex h-8 w-full min-w-0 items-center justify-between gap-2 rounded-lg px-2 py-1.5 text-n-slate-10 select-none',
            treeLine && treeVerticalLine,
            treeLine && (endTreeLine ? `before:h-3 ${treeElbow}` : 'before:-bottom-1'),
            collapsible && 'cursor-pointer hover:bg-n-alpha-2 pe-8',
            !collapsible && 'pointer-events-none',
          )}
        >
          <div className="inline-flex min-w-0 items-center gap-2">
            {subgroup.icon && <Icon name={subgroup.icon} className="size-4 flex-shrink-0" />}
            <span className="flex-grow truncate text-start text-sm font-medium leading-5">
              {subgroup.label}
            </span>
          </div>
        </div>
        {collapsible && (
          <div className="absolute end-2 top-1/2 flex -translate-y-1/2 items-center gap-1">
            <button
              type="button"
              aria-label={subgroup.label}
              aria-expanded={!minimized}
              onClick={onToggle}
              className="flex size-6 flex-shrink-0 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 focus-visible:outline-none"
            >
              <Icon
                name="ph-caret-up"
                className="size-3 flex-shrink-0 group-data-[minimized=true]/section:hidden"
              />
              <Icon
                name="ph-caret-down"
                className="size-3 flex-shrink-0 hidden group-data-[minimized=true]/section:inline-block"
              />
            </button>
          </div>
        )}
      </div>
      <ul
        className={cx(
          'm-0 list-none relative group min-w-0',
          collapsible && 'ms-5',
          treeLine && !endTreeLine && childrenTrunk,
        )}
      >
        <div
          data-section-scroll
          onScroll={onScroll}
          className={cx(
            'min-w-0',
            scrollable &&
              'group-data-[expanded=true]/nav:max-h-60 group-data-[expanded=true]/nav:overflow-y-scroll no-scrollbar',
          )}
        >
          {subgroup.children.map((leaf) => (
            <SidebarLeaf key={leaf.name} leaf={leaf} active={leaf.name === activeLeaf} inSubgroup />
          ))}
        </div>
        {scrollable && (
          <div className="absolute bg-linear-to-t from-n-background w-full h-12 to-transparent -bottom-1 pointer-events-none items-end justify-end px-2 hidden group-data-[expanded=true]/nav:flex group-data-[scroll-end=true]/section:hidden! group-data-[minimized=true]/section:hidden!">
            <Icon
              name="ph-caret-double-down"
              className="w-4 h-6 text-n-slate-9 opacity-50 group-hover:opacity-100"
            />
          </div>
        )}
      </ul>
    </li>
  )
}
