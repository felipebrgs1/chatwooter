import { render, screen } from '@testing-library/react'
import { I18nextProvider } from 'react-i18next'
import { expect, test } from 'vitest'

import { createI18n } from '../../i18n'
import { I18nT } from './i18n-t'

test('troca os placeholders por JSX e escolhe o plural', async () => {
  const i18n = await createI18n('en')
  const { container, rerender } = render(
    <I18nextProvider i18n={i18n}>
      <I18nT
        keypath="BULK_ACTION.ASSIGN_AGENT_CONFIRMATION_LABEL"
        plural={1}
        values={{ n: <strong>1</strong>, agentName: <strong>Ana</strong> }}
      />
    </I18nextProvider>,
  )
  expect(container.textContent).toBe('Are you sure you want to assign 1 conversation to Ana?')
  expect(screen.getByText('Ana').tagName).toBe('STRONG')

  rerender(
    <I18nextProvider i18n={i18n}>
      <I18nT
        keypath="BULK_ACTION.ASSIGN_AGENT_CONFIRMATION_LABEL"
        plural={3}
        values={{ n: <strong>3</strong>, agentName: <strong>Ana</strong> }}
      />
    </I18nextProvider>,
  )
  expect(container.textContent).toBe('Are you sure you want to assign 3 conversations to Ana?')
})
