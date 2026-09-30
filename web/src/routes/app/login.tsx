import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, redirect, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { profileQuery, signIn } from '../../api/auth'
import { LoginForm } from '../../components/auth/login-form'

// Só aceita voltar para dentro do app: "//evil.com" e URLs absolutas viram /app.
function safeRedirect(value: unknown): string {
  return typeof value === 'string' && /^\/app(\/|$|\?)/.test(value) ? value : '/app'
}

export const Route = createFileRoute('/app/login')({
  validateSearch: (search: Record<string, unknown>) => ({
    redirect: safeRedirect(search.redirect),
  }),
  // Quem já está logado não precisa ver o login.
  beforeLoad: async ({ context, search }) => {
    const profile = await context.queryClient.ensureQueryData(profileQuery).catch(() => null)
    if (profile) throw redirect({ to: search.redirect })
  },
  component: LoginPage,
})

// O Chatwoot troca o nome da instalação nos textos; aqui a instalação se chama Chatwooter.
const installationName = (text: string) => text.replace(/Chatwoot(?!er)/g, 'Chatwooter')

function LoginPage() {
  const { t } = useTranslation()
  const { redirect: target } = Route.useSearch()
  const queryClient = useQueryClient()
  const navigate = useNavigate()

  async function submit(email: string, password: string) {
    const profile = await signIn(email, password)
    queryClient.setQueryData(profileQuery.queryKey, profile)
    await navigate({ to: target })
  }

  return (
    <main className="flex min-h-screen w-full flex-col bg-n-brand/5 py-20 dark:bg-n-background sm:px-6 lg:px-8">
      <section className="mx-auto max-w-5xl">
        {/* O Chatwoot mostra o logo da instalação; o nosso logo ainda não existe. */}
        <h2 className="mt-6 text-center text-3xl font-medium text-n-slate-12">
          {installationName(t('LOGIN.TITLE'))}
        </h2>
      </section>
      <section className="mb-8 mt-11 bg-white p-11 shadow dark:bg-n-solid-2 sm:mx-auto sm:w-full sm:max-w-lg sm:rounded-lg sm:shadow-lg mt-15">
        <LoginForm onSubmit={submit} />
      </section>
    </main>
  )
}
