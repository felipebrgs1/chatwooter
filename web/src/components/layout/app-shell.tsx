// Casca do dashboard: sidebar + conteúdo (equivale a dashboard/components-next/sidebar + Dashboard.vue).
import { useQueryClient } from '@tanstack/react-query'
import { Link, Outlet, useNavigate, useRouterState } from '@tanstack/react-router'
import { useCallback, useState } from 'react'

import { profileQuery, signOut } from '../../api/auth'
import type { Profile } from '../../api/types'
import { Sidebar } from '../sidebar/sidebar'
import { SIDEBAR_DEFAULT_WIDTH } from '../sidebar/use-sidebar-resize'
import { useMediaQuery } from './use-media-query'
import { usePersistedState } from './use-persisted-state'

// lg do Tailwind: abaixo disso a sidebar vira flyout
const MOBILE_QUERY = '(max-width: 1023px)'

export function AppShell({ profile }: { profile: Profile }) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const isMobile = useMediaQuery(MOBILE_QUERY)
  const [mobileOpen, setMobileOpen] = useState(false)
  // Sem PUT /profile ainda: a largura e as seções minimizadas ficam no navegador (no Chatwoot, em ui_settings).
  const [width, setWidth] = usePersistedState('sidebar_width', SIDEBAR_DEFAULT_WIDTH)
  const [minimized, setMinimized] = usePersistedState<Record<string, boolean>>(
    'sidebar_minimized',
    {},
  )
  const activePath = useRouterState({
    select: (s) => s.location.pathname + (s.location.searchStr ?? ''),
  })

  const handleSignOut = useCallback(async () => {
    await signOut()
    queryClient.removeQueries({ queryKey: profileQuery.queryKey })
    await navigate({ to: '/app/login', search: { redirect: '/app' } })
  }, [navigate, queryClient])

  return (
    <div className="flex h-screen w-full overflow-hidden bg-n-background text-n-slate-12">
      <Sidebar
        profile={profile}
        currentAccountId={profile.account_id ?? profile.accounts[0]?.id ?? 0}
        activePath={activePath}
        width={width}
        isMobile={isMobile}
        onWidthChange={(next, commit) => commit && setWidth(next)}
        onToggleCollapse={() => setWidth((w) => (w < 160 ? SIDEBAR_DEFAULT_WIDTH : 56))}
        mobileOpen={mobileOpen}
        onMobileOpenChange={setMobileOpen}
        minimizedSections={minimized}
        onToggleSection={(key) => setMinimized((m) => ({ ...m, [key]: !m[key] }))}
        renderLink={({ to, children, ...rest }) => (
          <Link to={to} {...rest}>
            {children}
          </Link>
        )}
        onSignOut={handleSignOut}
        // Sem backend ainda (PUT /api/v1/profile/availability e troca de conta): o menu aparece, sem efeito.
        onAvailabilityChange={() => {}}
        onAutoOfflineChange={() => {}}
        onSwitchAccount={() => {}}
      />
      <main className="flex min-w-0 flex-1">
        <Outlet />
      </main>
    </div>
  )
}
