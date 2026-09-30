import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { beforeEach, expect, test } from 'vitest'

import type { ContactListItem } from '../../../api/types'
import { contactFixture } from '../../../test/conversation-fixtures'
import { profileFixture } from '../../../test/fixtures'
import { renderRoute } from '../../../test/render'
import { server } from '../../../test/server'
import { asSignedIn } from '../../../test/session'

let requests: URL[]

function contact(id: number, overrides: Partial<ContactListItem> = {}): ContactListItem {
  return contactFixture({ id, name: `Contato ${id}`, email: `c${id}@x.com`, ...overrides })
}

function respond(pages: ContactListItem[][], total = pages.flat().length) {
  server.use(
    http.get('/api/v1/accounts/1/contacts', ({ request }) => {
      const url = new URL(request.url)
      requests.push(url)
      const page = Number(url.searchParams.get('page'))
      return HttpResponse.json({
        meta: { count: total, current_page: String(page) },
        payload: pages[page - 1] ?? [],
      })
    }),
  )
}

beforeEach(() => {
  requests = []
  asSignedIn()
})

test('lista os contatos em cards com e-mail, telefone, empresa e local', async () => {
  respond([
    [
      contact(1, {
        name: 'Alice Contato',
        email: 'alice@acme.com',
        phone_number: '+5511999990000',
        additional_attributes: {
          company_name: 'Lumora Ltda',
          city: 'São Paulo',
          country_code: 'BR',
        },
      }),
      contact(2, { name: 'Bruno Lima' }),
    ],
  ])
  await renderRoute('/app/contacts')

  expect(await screen.findByText('Alice Contato')).toBeInTheDocument()
  expect(screen.getByRole('heading', { level: 1, name: 'Contacts' })).toBeInTheDocument()
  expect(screen.getByText('alice@acme.com')).toBeInTheDocument()
  expect(screen.getAllByText('+5511999990000')).toHaveLength(2)
  expect(screen.getByText('Lumora Ltda')).toBeInTheDocument()
  expect(screen.getByText('São Paulo, Brazil')).toBeInTheDocument()
  expect(screen.getByText('Bruno Lima')).toBeInTheDocument()
  expect(screen.getByText('Showing 1 - 2 of 2 contacts')).toBeInTheDocument()

  const params = requests.at(-1)!.searchParams
  expect(params.get('page')).toBe('1')
  expect(params.get('sort')).toBe('-last_activity_at')
  expect(params.get('include_contact_inboxes')).toBe('false')
})

test('a ordenação vem de ui_settings e trocar grava contacts_sort_by', async () => {
  asSignedIn(profileFixture({ ui_settings: { contacts_sort_by: 'email' } }))
  const saved: unknown[] = []
  server.use(
    http.put('/api/v1/profile', async ({ request }) => {
      const body = (await request.json()) as { profile: { ui_settings: Record<string, unknown> } }
      saved.push(body.profile.ui_settings)
      return HttpResponse.json(profileFixture({ ui_settings: body.profile.ui_settings }))
    }),
  )
  respond([[contact(1)]])
  await renderRoute('/app/contacts')
  await screen.findByText('Contato 1')
  expect(requests.at(-1)!.searchParams.get('sort')).toBe('email')

  const user = userEvent.setup()
  await user.click(screen.getByRole('button', { name: 'Sort by' }))
  await user.click(screen.getByRole('button', { name: 'Ascending' }))
  await user.click(
    within(screen.getByRole('listbox', { name: 'Ordering' })).getByRole('option', {
      name: 'Descending',
    }),
  )
  await waitFor(() => expect(saved.at(-1)).toMatchObject({ contacts_sort_by: '-email' }))
  await waitFor(() => expect(requests.at(-1)!.searchParams.get('sort')).toBe('-email'))
})

test('a paginação pede a próxima página e a guarda na URL', async () => {
  const first = Array.from({ length: 15 }, (_, i) => contact(i + 1))
  respond([first, [contact(16, { name: 'Última' })]], 16)
  const { router } = await renderRoute('/app/contacts')
  await screen.findByText('Contato 1')
  expect(screen.getByText('Showing 1 - 15 of 16 contacts')).toBeInTheDocument()

  const footer = screen.getByText('Showing 1 - 15 of 16 contacts').closest('div')!.parentElement!
  const buttons = within(footer).getAllByRole('button')
  await userEvent.click(buttons[2]!) // próxima
  expect(await screen.findByText('Última')).toBeInTheDocument()
  expect(requests.at(-1)!.searchParams.get('page')).toBe('2')
  expect(router.state.location.search).toMatchObject({ page: 2 })
})

test('a busca usa /contacts/search, muda o título e carrega mais resultados', async () => {
  respond([[contact(1)]])
  const searches: URL[] = []
  server.use(
    http.get('/api/v1/accounts/1/contacts/search', ({ request }) => {
      const url = new URL(request.url)
      searches.push(url)
      const page = Number(url.searchParams.get('page'))
      return HttpResponse.json({
        meta: { count: 1, current_page: String(page), has_more: page === 1 },
        payload: [contact(100 + page, { name: `Achado ${page}` })],
      })
    }),
  )
  const { router } = await renderRoute('/app/contacts')
  await screen.findByText('Contato 1')

  await userEvent.type(screen.getByRole('searchbox', { name: 'Search...' }), 'ana')
  expect(await screen.findByText('Achado 1')).toBeInTheDocument()
  expect(searches.at(-1)!.searchParams.get('q')).toBe('ana')
  expect(screen.getByRole('heading', { level: 1, name: 'Search contacts' })).toBeInTheDocument()
  expect(router.state.location.search).toMatchObject({ search: 'ana' })
  expect(screen.queryByText(/^Showing/)).not.toBeInTheDocument()

  await userEvent.click(screen.getByRole('button', { name: 'Load more' }))
  expect(await screen.findByText('Achado 2')).toBeInTheDocument()
  expect(screen.getByText('Achado 1')).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument()
})

test('busca sem resultado mostra a mensagem do Chatwoot', async () => {
  respond([[contact(1)]])
  server.use(
    http.get('/api/v1/accounts/1/contacts/search', () =>
      HttpResponse.json({ meta: { count: 0, current_page: '1', has_more: false }, payload: [] }),
    ),
  )
  await renderRoute('/app/contacts?search=zzz')
  expect(await screen.findByText('No contacts matches your search 🔍')).toBeInTheDocument()
})

test('conta sem contatos mostra o estado vazio', async () => {
  respond([[]])
  await renderRoute('/app/contacts')
  expect(await screen.findByText('No contacts found in this account')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Add contact' })).toBeInTheDocument()
})

test('"View details" abre o contato', async () => {
  respond([[contact(7, { name: 'Carla' })]])
  server.use(
    http.get('/api/v1/accounts/1/contacts/7', () =>
      HttpResponse.json({ payload: contact(7, { name: 'Carla' }) }),
    ),
  )
  const { router } = await renderRoute('/app/contacts')
  await screen.findByText('Carla')
  await userEvent.click(screen.getByRole('button', { name: 'View details' }))
  await waitFor(() => expect(router.state.location.pathname).toBe('/app/contacts/7'))
})

test('a sidebar leva à lista de contatos', async () => {
  respond([[contact(1)]])
  server.use(
    http.get('/api/v1/accounts/1/conversations', () =>
      HttpResponse.json({
        data: {
          meta: { mine_count: 0, assigned_count: 0, unassigned_count: 0, all_count: 0 },
          payload: [],
        },
      }),
    ),
  )
  const { router } = await renderRoute('/app')
  await userEvent.click(await screen.findByRole('link', { name: 'All Contacts' }))
  await waitFor(() => expect(router.state.location.pathname).toBe('/app/contacts'))
  expect(await screen.findByText('Contato 1')).toBeInTheDocument()
})
