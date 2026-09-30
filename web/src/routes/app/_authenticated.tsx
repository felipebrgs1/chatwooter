import { useSuspenseQuery } from '@tanstack/react-query'
import { createFileRoute, redirect } from '@tanstack/react-router'

import { profileQuery } from '../../api/auth'
import { ApiError } from '../../api/client'
import { AppShell } from '../../components/layout/app-shell'

// Tudo sob /app (menos o login) exige sessão; sem ela, vai para o login guardando o destino.
export const Route = createFileRoute('/app/_authenticated')({
  beforeLoad: async ({ context, location }) => {
    try {
      const profile = await context.queryClient.ensureQueryData(profileQuery)
      return { profile }
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        context.queryClient.removeQueries({ queryKey: profileQuery.queryKey })
        throw redirect({ to: '/app/login', search: { redirect: location.pathname } })
      }
      throw error
    }
  },
  component: Shell,
})

function Shell() {
  // O contexto da rota é só a foto do beforeLoad; o cache (que já está cheio) acompanha as gravações.
  const { data: profile } = useSuspenseQuery(profileQuery)
  return <AppShell profile={profile} />
}
