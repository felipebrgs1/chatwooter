import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { I18nextProvider } from 'react-i18next'

import { createI18n, resolveLocale } from './i18n'
import { createAppRouter } from './router'
import './styles/app.css'

const queryClient = new QueryClient()
const router = createAppRouter(queryClient)
const i18n = await createI18n(resolveLocale(navigator.language))

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <I18nextProvider i18n={i18n}>
        <RouterProvider router={router} />
      </I18nextProvider>
    </QueryClientProvider>
  </StrictMode>,
)
