import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { beforeEach, expect, test } from 'vitest'

import { profileFixture } from '../../../test/fixtures'
import { renderRoute } from '../../../test/render'
import { server } from '../../../test/server'
import { asSignedIn } from '../../../test/session'

const company = {
  id: 7,
  name: 'Acme',
  domain: 'acme.example',
  description: 'Support',
  contacts_count: null,
  custom_attributes: {},
  avatar_url: '',
  created_at: 1790000000,
  updated_at: 1790000000,
}
let requests: URL[]
beforeEach(() => {
  asSignedIn()
  requests = []
  server.use(
    http.get('/api/v1/accounts/1/companies', ({ request }) => {
      requests.push(new URL(request.url))
      return HttpResponse.json({ meta: { total_count: 1, page: 1 }, payload: [company] })
    }),
    http.get('/api/v1/accounts/1/companies/7', () => HttpResponse.json({ payload: company })),
  )
})

test('sidebar leva à lista e card abre o detalhe na rota gerada', async () => {
  await renderRoute('/app/companies')
  expect(await screen.findByRole('heading', { name: 'Companies', level: 1 })).toBeInTheDocument()
  expect(screen.getByRole('link', { name: 'All Companies' })).toHaveAttribute(
    'aria-current',
    'page',
  )
  await userEvent.click(await screen.findByRole('button', { name: /Acme.*acme.example/ }))
  expect(await screen.findByRole('textbox', { name: 'Name' })).toHaveValue('Acme')
})

test('sort salvo no perfil é usado e mudar a ordem persiste sem perder outras preferências', async () => {
  asSignedIn(
    profileFixture({ ui_settings: { companies_sort_by: 'domain', contacts_sort_by: 'email' } }),
  )
  const saved: unknown[] = []
  server.use(
    http.put('/api/v1/profile', async ({ request }) => {
      const body = (await request.json()) as { profile: { ui_settings: Record<string, unknown> } }
      saved.push(body.profile.ui_settings)
      return HttpResponse.json(profileFixture({ ui_settings: body.profile.ui_settings }))
    }),
  )
  await renderRoute('/app/companies')
  await screen.findByText('Acme')
  expect(requests.at(-1)!.searchParams.get('sort')).toBe('domain')
  await userEvent.click(screen.getByRole('button', { name: 'Sort by' }))
  await userEvent.click(screen.getByRole('button', { name: 'Ascending' }))
  await userEvent.click(
    within(screen.getByRole('listbox', { name: 'Order' })).getByRole('option', {
      name: 'Descending',
    }),
  )
  await waitFor(() =>
    expect(saved).toEqual([{ companies_sort_by: '-domain', contacts_sort_by: 'email' }]),
  )
  await waitFor(() => expect(requests.at(-1)!.searchParams.get('sort')).toBe('-domain'))
})
