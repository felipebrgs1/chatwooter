// Casca do dashboard: sidebar + conteúdo (equivale a dashboard/components-next/sidebar + Dashboard.vue).
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, Outlet, useNavigate, useRouterState } from '@tanstack/react-router'
import { useCallback, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import type { Availability } from '../../api/types'

import {
  profileQuery,
  setActiveAccount,
  setAutoOffline,
  setAvailability,
  signOut,
  updateUiSettings,
} from '../../api/auth'
import { inboxesQuery } from '../../api/inboxes'
import { customFiltersQuery } from '../../api/custom-filters'
import { labelsQuery } from '../../api/labels'
import { teamsQuery } from '../../api/teams'
import type { Profile } from '../../api/types'
import type { SidebarLinkProps } from '../sidebar/link-context'
import { Sidebar } from '../sidebar/sidebar'
import { buildMenu } from '../sidebar/sidebar-menu'
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
  const { t } = useTranslation()
  const { data: teams } = useQuery(teamsQuery(accountId))
  const { data: inboxes } = useQuery(inboxesQuery(accountId))
  const { data: labels } = useQuery(labelsQuery(accountId))
  const { data: folders } = useQuery(customFiltersQuery(accountId))
  const menu = useMemo(
    () => buildMenu((key) => t(key), { teams, inboxes, labels, folders }),
    [t, teams, inboxes, labels, folders],
  )
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
        menu={menu}
        renderLink={routerLink}
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

// O <Link> do TanStack não aceita query no `to`: separa o caminho e passa os params como search.
// Números viram number (team_id=2), senão o roteador os serializaria entre aspas.
function routerLink({ to, children, ...rest }: SidebarLinkProps) {
  const url = new URL(to, 'http://x')
  const search = Object.fromEntries(
    [...url.searchParams].map(([k, v]) => [k, /^\d+$/.test(v) ? Number(v) : v]),
  )
  return (
    <Link to={url.pathname} search={search} {...rest}>
      {children}
    </Link>
  )
}
