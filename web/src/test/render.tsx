import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createMemoryHistory, RouterProvider } from '@tanstack/react-router'
import { render } from '@testing-library/react'
import { I18nextProvider } from 'react-i18next'

import { createI18n } from '../i18n'
import { createAppRouter } from '../router'

// Monta o app inteiro (providers + roteador) na URL dada; a API é a falsa de src/test/server.ts.
export async function renderRoute(path: string, options: { locale?: string } = {}) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  const i18n = await createI18n(options.locale ?? 'en')
  const router = createAppRouter(queryClient, createMemoryHistory({ initialEntries: [path] }))
  await router.load()
  const utils = render(
    <QueryClientProvider client={queryClient}>
      <I18nextProvider i18n={i18n}>
        <RouterProvider router={router} />
      </I18nextProvider>
    </QueryClientProvider>,
  )
  return { ...utils, router, queryClient, i18n }
}
