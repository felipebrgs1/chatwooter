import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { expect, test, vi } from 'vitest'

import { profileFixture } from '../../test/fixtures'
import { renderRoute } from '../../test/render'
import { asSignedIn } from '../../test/session'
import { server } from '../../test/server'

// O perfil devolvido pelo servidor falso reflete o que foi gravado, como o real.
function statefulProfile() {
  let profile = profileFixture()
  server.use(
    http.get('/api/v1/profile', () => HttpResponse.json(profile)),
    http.get('/api/v1/accounts/:id/conversations', () =>
      HttpResponse.json({
        data: {
          meta: { mine_count: 0, assigned_count: 0, unassigned_count: 0, all_count: 0 },
          payload: [],
        },
      }),
    ),
  )
  return {
    set: (next: typeof profile) => (profile = next),
    get: () => profile,
  }
}

test('mudar a disponibilidade chama a API e atualiza o perfil', async () => {
  const state = statefulProfile()
  const called = vi.fn()
  server.use(
    http.post('/api/v1/profile/availability', async ({ request }) => {
      const body = (await request.json()) as {
        profile: { account_id: number; availability: string }
      }
      called(body.profile)
      const p = state.get()
      state.set({
        ...p,
        accounts: p.accounts.map((a) =>
          a.id === body.profile.account_id
            ? { ...a, availability: 'busy' as const, availability_status: 'busy' as const }
            : a,
        ),
      })
      return HttpResponse.json(state.get())
    }),
  )
  await renderRoute('/app')
  const user = userEvent.setup()

  await user.click(await screen.findByText('Ana Souza'))
  await user.click(await screen.findByRole('button', { name: 'Online' }))
  await user.click(await screen.findByRole('button', { name: 'Busy' }))

  await waitFor(() => expect(called).toHaveBeenCalledWith({ account_id: 1, availability: 'busy' }))
})

test('trocar de conta marca a conta como ativa e recarrega o perfil', async () => {
  const state = statefulProfile()
  const switched = vi.fn()
  server.use(
    http.put('/api/v1/profile/set_active_account', async ({ request }) => {
      const body = (await request.json()) as { profile: { account_id: number } }
      switched(body.profile.account_id)
      state.set({ ...state.get(), account_id: body.profile.account_id })
      return new HttpResponse(null, { status: 200 })
    }),
  )
  await renderRoute('/app')
  const user = userEvent.setup()

  await user.click(await screen.findByText('Acme'))
  await user.click(await screen.findByText('Globex'))

  await waitFor(() => expect(switched).toHaveBeenCalledWith(2))
  await waitFor(() => expect(screen.getByText('Globex')).toBeInTheDocument())
})

test('a largura da sidebar é gravada em ui_settings', async () => {
  asSignedIn()
  const saved = vi.fn()
  server.use(
    http.get('/api/v1/accounts/:id/conversations', () =>
      HttpResponse.json({
        data: {
          meta: { mine_count: 0, assigned_count: 0, unassigned_count: 0, all_count: 0 },
          payload: [],
        },
      }),
    ),
    http.put('/api/v1/profile', async ({ request }) => {
      saved(await request.json())
      return HttpResponse.json(profileFixture())
    }),
  )
  await renderRoute('/app')
  const user = userEvent.setup()

  const aside = await screen.findByRole('complementary')
  await user.dblClick(aside.querySelector('#sidebar-resize-handle') as Element)

  // o duplo clique também dispara mousedown/up do arrasto (grava a largura atual); o que vale é o último
  await waitFor(() =>
    expect(saved).toHaveBeenLastCalledWith({ profile: { ui_settings: { sidebar_width: 56 } } }),
  )
})

test('a sidebar lista times e etiquetas e filtra a lista por eles', async () => {
  statefulProfile()
  server.use(
    http.get('/api/v1/accounts/1/teams', () =>
      HttpResponse.json([
        {
          id: 2,
          name: 'Suporte',
          description: null,
          allow_auto_assign: true,
          icon: '',
          icon_color: '',
          account_id: 1,
          is_member: true,
        },
      ]),
    ),
    http.get('/api/v1/accounts/1/labels', () =>
      HttpResponse.json({
        payload: [
          { id: 5, title: 'vip', description: null, color: '#00ff00', show_on_sidebar: true },
        ],
      }),
    ),
  )
  const { router } = await renderRoute('/app')
  const user = userEvent.setup()

  await user.click(await screen.findByRole('link', { name: 'Suporte' }))
  await waitFor(() => expect(router.state.location.search).toMatchObject({ team_id: 2 }))
  expect(screen.getByRole('link', { name: 'Suporte' })).toHaveAttribute('aria-current', 'page')

  await user.click(screen.getByRole('link', { name: 'vip' }))
  await waitFor(() => expect(router.state.location.search).toMatchObject({ label: 'vip' }))
  expect(router.state.location.search).not.toHaveProperty('team_id')
})
