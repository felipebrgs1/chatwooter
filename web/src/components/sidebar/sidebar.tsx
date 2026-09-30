// Port de sidebar/Sidebar.vue (+ provider.js). Só apresentação: largura, abertura no mobile e seções
// minimizadas são estado do pai; nada aqui fala com a API.
import { useEffect, useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'

import type { Availability, Profile } from '../../api/types'
import { cx } from '../next/cx'
import { LinkProvider, type LinkRenderer } from './link-context'
import { MobileLauncher } from './mobile-launcher'
import { ProfileMenu } from './profile-menu'
import { SidebarCollapsedGroup } from './sidebar-collapsed-group'
import { SidebarCollapsedPopover } from './sidebar-collapsed-popover'
import { SidebarGroup } from './sidebar-group'
import { SidebarHeader } from './sidebar-header'
import { activeLeaf as findActiveLeaf, buildMenu, type MenuGroup } from './sidebar-menu'
import { usePopoverState } from './use-popover-state'
import { isCollapsed, useSidebarResize } from './use-sidebar-resize'

export type SidebarProps = {
  profile: Profile
  currentAccountId: number
  /** Caminho atual com query (`/app?team_id=2`), para marcar o item ativo. */
  activePath: string | null
  /** Menu; o padrão é o do Chatwoot com as telas que já existem. */
  menu?: MenuGroup[]
  width: number
  isMobile?: boolean
  /** `commit` é falso durante o arraste e verdadeiro ao soltar (aí persiste). */
  onWidthChange: (width: number, commit: boolean) => void
  onToggleCollapse: () => void
  mobileOpen: boolean
  onMobileOpenChange: (open: boolean) => void
  hideMobileLauncher?: boolean
  /** Seções recolhidas, por `conta:grupo:seção`. */
  minimizedSections?: Record<string, boolean>
  onToggleSection?: (key: string) => void
  /** Injeta o <Link> do roteador; sem isso os links são <a href> comuns. */
  renderLink?: LinkRenderer
  onSignOut: () => void
  onAvailabilityChange: (availability: Availability) => void
  onAutoOfflineChange: (autoOffline: boolean) => void
  onSwitchAccount: (accountId: number) => void
  onCompose?: () => void
}

const noSections: Record<string, boolean> = {}

export function Sidebar(props: SidebarProps) {
  const { profile, currentAccountId, width, isMobile = false, mobileOpen } = props
  const { t } = useTranslation()
  const asideRef = useRef<HTMLElement>(null)
  const popover = usePopoverState()
  const resize = useSidebarResize(width, props.onWidthChange)

  const menu = useMemo(() => props.menu ?? buildMenu((key) => t(key)), [props.menu, t])
  const activeLeaf = findActiveLeaf(menu, props.activePath)
  const collapsed = isCollapsed(width, isMobile)
  const membership = profile.accounts.find((a) => a.id === currentAccountId)

  // Flyout mobile: clicar fora fecha (o launcher abre/fecha por conta própria)
  const { onMobileOpenChange } = props
  useEffect(() => {
    if (!mobileOpen) return
    const onClick = (event: MouseEvent) => {
      const target = event.target as Element
      if (asideRef.current?.contains(target) || target.closest('#mobile-sidebar-launcher')) return
      onMobileOpenChange(false)
    }
    document.addEventListener('click', onClick)
    return () => document.removeEventListener('click', onClick)
  }, [mobileOpen, onMobileOpenChange])

  return (
    <LinkProvider value={props.renderLink ?? defaultRenderer}>
      <aside
        id="app-sidebar"
        ref={asideRef}
        data-collapsed={String(collapsed)}
        data-mobile-open={String(mobileOpen)}
        data-resizing={resize.resizing ? 'true' : undefined}
        style={{ '--sidebar-width': `${width}px` } as React.CSSProperties}
        className="group/sidebar peer bg-n-background flex flex-col text-sm pb-px fixed top-0 left-0 h-full z-40 w-[200px] md:w-(--sidebar-width) md:relative md:flex-shrink-0 md:translate-x-0 border-r border-n-weak -translate-x-full data-[mobile-open=true]:translate-x-0 data-[mobile-open=true]:shadow-lg md:data-[mobile-open=true]:shadow-none transition-transform duration-200 ease-out md:transition-[width] data-[resizing=true]:transition-none"
      >
        <SidebarHeader
          accounts={profile.accounts}
          currentAccountId={currentAccountId}
          collapsed={collapsed}
          onSwitchAccount={props.onSwitchAccount}
          onCompose={props.onCompose}
        />

        <nav
          className={cx(
            'grid overflow-y-scroll flex-grow gap-2 pb-5 no-scrollbar min-w-0',
            collapsed ? 'px-1' : 'px-2',
          )}
        >
          <ul
            className={cx('flex flex-col gap-1 m-0 list-none min-w-0', collapsed && 'items-center')}
          >
            {menu.map((group) =>
              collapsed ? (
                <SidebarCollapsedGroup
                  key={group.name}
                  group={group}
                  activeLeaf={activeLeaf}
                  onHover={(event) =>
                    popover.open(group.name, event.currentTarget, asideRef.current)
                  }
                  onLeave={() => popover.scheduleClose(200)}
                />
              ) : (
                <SidebarGroup
                  key={group.name}
                  group={group}
                  activeLeaf={activeLeaf}
                  accountId={currentAccountId}
                  minimizedSections={props.minimizedSections ?? noSections}
                  onToggleSection={props.onToggleSection ?? noop}
                />
              ),
            )}
          </ul>
        </nav>

        {/* Fora do <nav> para não ser cortado pelo overflow dele */}
        {collapsed &&
          menu.map((group) => (
            <SidebarCollapsedPopover
              key={group.name}
              group={group}
              activeLeaf={activeLeaf}
              popover={popover.active}
              onEnter={popover.cancel}
              onLeave={() => popover.scheduleClose(100)}
              onNavigate={popover.close}
            />
          ))}

        <section className="flex relative flex-col flex-shrink-0 gap-1 justify-between items-center">
          <div className="pointer-events-none absolute inset-x-0 -top-[1.938rem] h-8 bg-linear-to-t from-n-background to-transparent" />
          <div
            className={cx(
              'px-1 py-1.5 flex-shrink-0 flex w-full z-50 gap-2 items-center border-t border-n-weak shadow-sidebar-profile',
              collapsed ? 'justify-center' : 'justify-between',
            )}
          >
            <ProfileMenu
              name={profile.available_name}
              email={profile.email}
              availability={membership?.availability ?? 'offline'}
              autoOffline={membership?.auto_offline ?? false}
              collapsed={collapsed}
              onAvailabilityChange={props.onAvailabilityChange}
              onAutoOfflineChange={props.onAutoOfflineChange}
              onSignOut={props.onSignOut}
            />
          </div>
        </section>

        <div
          id="sidebar-resize-handle"
          data-resize-handle
          onDoubleClick={props.onToggleCollapse}
          {...resize.handleProps}
          className="hidden md:block absolute top-0 h-full w-1 cursor-col-resize z-40 right-0 group"
        >
          <div className="absolute top-0 h-full w-px right-0 bg-transparent group-hover:bg-n-brand transition-colors group-data-[resizing=true]/sidebar:bg-n-brand" />
        </div>
      </aside>

      {!props.hideMobileLauncher && (
        <MobileLauncher onToggle={() => onMobileOpenChange(!mobileOpen)} />
      )}
    </LinkProvider>
  )
}

const noop = () => {}
const defaultRenderer: LinkRenderer = ({ to, children, ...rest }) => (
  <a href={to} {...rest}>
    {children}
  </a>
)
