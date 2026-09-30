import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import type { ReactElement } from 'react'
import { I18nextProvider } from 'react-i18next'

import { profileQuery } from '../../api/auth'
import { createI18n } from '../../i18n'
import { profileFixture } from '../../test/fixtures'
import { server } from '../../test/server'
import { Toaster } from '../toast/toaster'

// Renderiza uma peça da conversa com Query, i18n (en) e toasts, logado como a Ana (conta 1).
export async function renderConversation(ui: ReactElement) {
  server.use(http.get('/api/v1/profile', () => HttpResponse.json(profileFixture())))
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  // Na app o guard de /app/* já deixou o perfil no cache antes de qualquer tela renderizar
  queryClient.setQueryData(profileQuery.queryKey, profileFixture())
  const i18n = await createI18n('en')
  const utils = render(
    <QueryClientProvider client={queryClient}>
      <I18nextProvider i18n={i18n}>
        {ui}
        <Toaster />
      </I18nextProvider>
    </QueryClientProvider>,
  )
  return { ...utils, queryClient }
}
