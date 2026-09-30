import { render } from '@testing-library/react'
import type { ReactElement } from 'react'
import { I18nextProvider } from 'react-i18next'

import { createI18n } from '../i18n'

// Renderiza com o i18n real (textos do Chatwoot), no idioma pedido.
export async function renderWithI18n(ui: ReactElement, locale = 'en') {
  const i18n = await createI18n(locale)
  return render(<I18nextProvider i18n={i18n}>{ui}</I18nextProvider>)
}
