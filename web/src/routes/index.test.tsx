import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'

import { renderRoute } from '../test/render'

test('a raiz mostra o shell do app', async () => {
  await renderRoute('/')
  expect(await screen.findByRole('heading', { name: 'Chatwooter' })).toBeInTheDocument()
})
