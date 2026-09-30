// Casca do dashboard: sidebar + conteúdo (equivale a dashboard/components-next/sidebar + Dashboard.vue).
import { useQueryClient } from '@tanstack/react-query'
import { Link, Outlet, useNavigate, useRouterState } from '@tanstack/react-router'
import { useCallback, useState } from 'react'

import type { Availability } from '../../api/types'

import {
  profileQuery,
  setActiveAccount,
  setAutoOffline,
  setAvailability,
  signOut,
  updateUiSettings,
} from '../../api/auth'
import type { Profile } from '../../api/types'
import { Sidebar } from '../sidebar/sidebar'
import {
  SIDEBAR_COLLAPSED_THRESHOLD,
  SIDEBAR_DEFAULT_WIDTH,
  SIDEBAR_MIN_WIDTH,
} from '../sidebar/use-sidebar-resize'
import { useMediaQuery } from './use-media-query'
import { usePersistedState } from './use-persisted-state'

// lg do Tailwind: abaixo disso a sidebar vira flyout
const MOBILE_QUERY = '(max-width: 1023px)'

export function AppShell({ profile }: { profile: Profile }) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const isMobile = useMediaQuery(MOBILE_QUERY)
  const [mobileOpen, setMobileOpen] = useState(false)
  // A largura vive em ui_settings (como no Chatwoot); as seções minimizadas ficam no localStorage, também como lá.
  const savedWidth = profile.ui_settings.sidebar_width
  const [dragWidth, setDragWidth] = useState<number | null>(null)
  const width = dragWidth ?? (typeof savedWidth === 'number' ? savedWidth : SIDEBAR_DEFAULT_WIDTH)
  const [minimized, setMinimized] = usePersistedState<Record<string, boolean>>(
    'sidebar_minimized',
    {},
  )
  const activePath = useRouterState({
    select: (s) => s.location.pathname + (s.location.searchStr ?? ''),
  })

  const switchAccount = useCallback(
    async (id: number) => {
      await setActiveAccount(id)
      // os dados em cache são da conta anterior
      queryClient.removeQueries({ queryKey: ['accounts'] })
      await queryClient.invalidateQueries({ queryKey: profileQuery.queryKey })
      await navigate({ to: '/app' })
    },
    [navigate, queryClient],
  )

  const handleSignOut = useCallback(async () => {
    await signOut()
    queryClient.removeQueries({ queryKey: profileQuery.queryKey })
    await navigate({ to: '/app/login', search: { redirect: '/app' } })
  }, [navigate, queryClient])

  const accountId = profile.account_id ?? profile.accounts[0]?.id ?? 0
  const replaceProfile = (next: Profile | null | undefined) => {
    if (next) queryClient.setQueryData(profileQuery.queryKey, next)
  }

  const commitWidth = useCallback(
    async (next: number) => {
      setDragWidth(next)
      try {
        replaceProfile(await updateUiSettings({ ...profile.ui_settings, sidebar_width: next }))
      } finally {
        setDragWidth(null)
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [profile.ui_settings],
  )

  return (
    <div className="flex h-screen w-full overflow-hidden bg-n-background text-n-slate-12">
      <Sidebar
        profile={profile}
        currentAccountId={accountId}
        activePath={activePath}
        width={width}
        isMobile={isMobile}
        onWidthChange={(next, commit) => (commit ? void commitWidth(next) : setDragWidth(next))}
        onToggleCollapse={() =>
          void commitWidth(
            width < SIDEBAR_COLLAPSED_THRESHOLD ? SIDEBAR_DEFAULT_WIDTH : SIDEBAR_MIN_WIDTH,
          )
        }
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
        onAvailabilityChange={(availability: Availability) =>
          void setAvailability(accountId, availability).then(replaceProfile)
        }
        onAutoOfflineChange={(autoOffline) =>
          void setAutoOffline(accountId, autoOffline).then(replaceProfile)
        }
        onSwitchAccount={(id) => void switchAccount(id)}
      />
      <main className="flex min-w-0 flex-1">
        <Outlet />
      </main>
    </div>
  )
}
