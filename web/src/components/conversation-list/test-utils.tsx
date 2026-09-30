import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import type { ReactElement } from 'react'
import { I18nextProvider } from 'react-i18next'

import { createI18n } from '../../i18n'
import { profileFixture } from '../../test/fixtures'

// Renderiza um componente da lista com i18n, React Query e o perfil já no cache (a área autenticada o garante).
export async function renderWithApp(ui: ReactElement) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  queryClient.setQueryData(['profile'], profileFixture())
  const i18n = await createI18n('en')
  // wrapper (e não JSX em volta) para o `rerender` do teste manter os providers
  function Providers({ children }: { children: React.ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <I18nextProvider i18n={i18n}>{children}</I18nextProvider>
      </QueryClientProvider>
    )
  }
  return { queryClient, ...render(ui, { wrapper: Providers }) }
}
