import { createRootRouteWithContext, Outlet } from '@tanstack/react-router'

import { Toaster } from '../components/toast/toaster'
import type { RouterContext } from '../router'

export const Route = createRootRouteWithContext<RouterContext>()({
  component: () => (
    <>
      <Outlet />
      <Toaster />
    </>
  ),
})
