import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, test, vi } from 'vitest'

import { profileFixture } from '../../test/fixtures'
import { asGuest, asSignedIn } from '../../test/session'
import { renderRoute } from '../../test/render'
import { server } from '../../test/server'

async function fillAndSubmit(email: string, password: string) {
  const user = userEvent.setup()
  await user.type(await screen.findByLabelText('Email'), email)
  await user.type(screen.getByLabelText(/^Password/), password)
  await user.click(screen.getByRole('button', { name: 'Login' }))
}

const profile = profileFixture()

describe('tela de login (/app/login)', () => {
  test('mostra título, campos e botão como o Chatwoot', async () => {
    asGuest()
    await renderRoute('/app/login')
    expect(await screen.findByRole('heading', { name: 'Login to Chatwooter' })).toBeInTheDocument()
    expect(screen.getByLabelText('Email')).toHaveAttribute('placeholder', 'example@companyname.com')
    expect(screen.getByLabelText(/^Password/)).toHaveAttribute('type', 'password')
    expect(screen.getByRole('button', { name: 'Login' })).toBeEnabled()
  })

  test('login correto entra no app e guarda o perfil', async () => {
    asGuest()
    const signIn = vi.fn()
    server.use(
      http.post('/auth/sign_in', async ({ request }) => {
        signIn(await request.json())
        return HttpResponse.json({ data: profile })
      }),
    )
    const { router, queryClient } = await renderRoute('/app/login')

    await fillAndSubmit('ana@example.com', 'segredo')

    await waitFor(() => expect(router.state.location.pathname).toBe('/app'))
    expect(signIn).toHaveBeenCalledWith({ email: 'ana@example.com', password: 'segredo' })
    expect(queryClient.getQueryData(['profile'])).toEqual(profile)
  })

  test('credenciais erradas mostram o aviso e não saem da tela', async () => {
    asGuest()
    server.use(
      http.post('/auth/sign_in', () =>
        HttpResponse.json(
          { success: false, errors: ['Invalid login credentials. Please try again.'] },
          { status: 401 },
        ),
      ),
    )
    const { router } = await renderRoute('/app/login')

    await fillAndSubmit('ana@example.com', 'errada')

    expect(await screen.findByRole('status')).toHaveTextContent(
      'Username or password is incorrect. Please try again.',
    )
    expect(router.state.location.pathname).toBe('/app/login')
    expect(screen.getByRole('button', { name: 'Login' })).toBeEnabled()
  })

  test('e-mail sem formato válido avisa e nem chama a API', async () => {
    asGuest()
    const signIn = vi.fn()
    server.use(http.post('/auth/sign_in', () => (signIn(), HttpResponse.json({}))))
    await renderRoute('/app/login')

    await fillAndSubmit('isso-nao-e-email', 'segredo')

    expect(await screen.findByRole('status')).toHaveTextContent(
      'Please enter a valid email address',
    )
    expect(signIn).not.toHaveBeenCalled()
  })

  test('o botão de olho mostra e esconde a senha', async () => {
    asGuest()
    await renderRoute('/app/login')
    const user = userEvent.setup()
    const password = await screen.findByLabelText(/^Password/)

    await user.click(screen.getByRole('button', { name: 'Show password' }))
    expect(password).toHaveAttribute('type', 'text')
    expect(screen.getByRole('button', { name: 'Hide password' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )

    await user.click(screen.getByRole('button', { name: 'Hide password' }))
    expect(password).toHaveAttribute('type', 'password')
  })

  test('quem já tem sessão é mandado para o app', async () => {
    asSignedIn()
    const { router } = await renderRoute('/app/login')
    await waitFor(() => expect(router.state.location.pathname).toBe('/app'))
  })

  test('ignora redirect para fora do app', async () => {
    asGuest()
    server.use(http.post('/auth/sign_in', () => HttpResponse.json({ data: profile })))
    const { router } = await renderRoute('/app/login?redirect=https://evil.example')
    await fillAndSubmit('ana@example.com', 'segredo')
    await waitFor(() => expect(router.state.location.pathname).toBe('/app'))
    expect(router.state.location.href).not.toContain('evil')
  })
})
