// Port de sidebar/SidebarGroupLeaf.vue (ramo expandido).
import { ChannelIcon } from '../next/channel-icon'
import { cx } from '../next/cx'
import { Icon } from '../next/icon'
import { SidebarLink } from './link-context'
import type { MenuLeaf } from './sidebar-menu'
import { thinTreeLine, treeConnector } from './tree-classes'

type Props = { leaf: MenuLeaf; active: boolean; inSubgroup?: boolean }

const rowClasses =
  'flex h-8 items-center gap-2 px-2 py-1 rounded-lg hover:bg-linear-to-r from-transparent via-n-slate-3/70 to-n-slate-3/70 group min-w-0'

function LeafContent({ leaf }: { leaf: MenuLeaf }) {
  if (leaf.channel) {
    return (
      <>
        <span className="size-4 grid place-content-center rounded-full">
          <ChannelIcon channel={leaf.channel} className="size-4" />
        </span>
        <div className="flex-1 truncate min-w-0">{leaf.label}</div>
      </>
    )
  }
  return (
    <>
      {leaf.color && (
        <span className="size-4 grid place-content-center rounded-full">
          <span className="size-[8px] rounded-sm" style={{ backgroundColor: leaf.color }} />
        </span>
      )}
      {leaf.icon && (
        <span className="size-4 grid place-content-center rounded-full">
          <Icon name={leaf.icon} className="size-4 inline-block" />
        </span>
      )}
      <div className="flex-1 truncate min-w-0 text-sm">{leaf.label}</div>
    </>
  )
}

// Fora do subgrupo, com o grupo recolhido só a folha ativa aparece.
export function SidebarLeaf({ leaf, active, inSubgroup = false }: Props) {
  const row = cx(rowClasses, active && 'text-n-slate-12 bg-n-alpha-2 active')
  return (
    <li
      className={cx(
        'py-0.5 ps-2 ms-3 relative text-n-slate-11 min-w-0',
        treeConnector,
        inSubgroup && thinTreeLine,
        inSubgroup &&
          'group-data-[expanded=false]/nav:before:hidden group-data-[expanded=false]/nav:after:hidden group-data-[minimized=true]/section:hidden!',
        !active && 'hidden group-data-[expanded=true]/nav:block',
      )}
    >
      {leaf.to ? (
        <SidebarLink
          id={`sidebar-${leaf.name}`}
          to={leaf.to}
          title={leaf.label}
          aria-current={active ? 'page' : undefined}
          className={row}
        >
          <LeafContent leaf={leaf} />
        </SidebarLink>
      ) : (
        // sem rota ainda: aparece só visual, nunca como link quebrado
        <div id={`sidebar-${leaf.name}`} title={leaf.label} className={row}>
          <LeafContent leaf={leaf} />
        </div>
      )}
    </li>
  )
}
