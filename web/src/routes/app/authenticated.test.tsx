import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { expect, test } from 'vitest'

import { asGuest, asSignedIn } from '../../test/session'
import { renderRoute } from '../../test/render'
import { server } from '../../test/server'

test('visitante em /app vai para o login guardando o destino', async () => {
  asGuest()
  const { router } = await renderRoute('/app')
  await waitFor(() => expect(router.state.location.pathname).toBe('/app/login'))
  expect(router.state.location.search).toMatchObject({ redirect: '/app' })
  expect(await screen.findByRole('heading', { name: 'Login to Chatwooter' })).toBeInTheDocument()
})

test('a raiz / leva para /app', async () => {
  asSignedIn()
  const { router } = await renderRoute('/')
  await waitFor(() => expect(router.state.location.pathname).toBe('/app'))
})

test('logado, /app mostra a sidebar e a área de conteúdo', async () => {
  asSignedIn()
  await renderRoute('/app')
  expect(await screen.findByRole('navigation')).toBeInTheDocument()
  expect(screen.getByRole('link', { name: /All Conversations/ })).toHaveAttribute('href', '/app')
  expect(screen.getByRole('main')).toBeInTheDocument()
})

test('sair encerra a sessão e volta para o login', async () => {
  asSignedIn()
  let signedOut = false
  server.use(
    http.delete('/auth/sign_out', () => {
      signedOut = true
      asGuest() // a sessão foi revogada: o perfil passa a responder 401
      return HttpResponse.json({ success: true })
    }),
  )
  const { router } = await renderRoute('/app')
  const user = userEvent.setup()

  await user.click(await screen.findByText('Ana Souza'))
  await user.click(screen.getByRole('button', { name: 'Log out' }))

  await waitFor(() => expect(router.state.location.pathname).toBe('/app/login'))
  expect(signedOut).toBe(true)
})
