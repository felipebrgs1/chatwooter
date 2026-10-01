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

test('a seta expande a edição rápida, salva e descarta alterações ao reabrir', async () => {
  let current = contact(1)
  const updates: unknown[] = []
  server.use(
    http.get('/api/v1/accounts/1/contacts', () =>
      HttpResponse.json({
        meta: { count: 1, current_page: '1' },
        payload: [current],
      }),
    ),
    http.put('/api/v1/accounts/1/contacts/1', async ({ request }) => {
      const data = (await request.json()) as Partial<ContactListItem>
      updates.push(data)
      current = { ...current, ...data }
      return HttpResponse.json({ payload: current })
    }),
  )
  await renderRoute('/app/contacts')
  await screen.findByText('Contato 1')
  const user = userEvent.setup()
  const toggle = screen.getByRole('button', { name: 'Edit contact details' })
  await user.click(toggle)
  expect(toggle).toHaveAttribute('aria-expanded', 'true')
  const firstName = screen.getByPlaceholderText('Enter the first name')
  await user.clear(firstName)
  expect(screen.getByRole('button', { name: 'Update contact' })).toBeDisabled()
  await user.type(firstName, 'Alice')
  await user.click(screen.getByRole('button', { name: 'Update contact' }))
  await waitFor(() => expect(updates).toHaveLength(1))
  expect(updates[0]).toMatchObject({ name: 'Alice 1' })
  await screen.findByText('Alice 1')
  await user.clear(firstName)
  await user.type(firstName, 'Unsaved')
  await user.click(toggle)
  expect(screen.queryByPlaceholderText('Enter the first name')).not.toBeInTheDocument()
  await user.click(toggle)
  expect(screen.getByPlaceholderText('Enter the first name')).toHaveValue('Alice')
})

test('a lista abre um card por vez e exige confirmação para excluir', async () => {
  let remaining = [contact(1), contact(2)]
  const deleted: string[] = []
  server.use(
    http.get('/api/v1/accounts/1/contacts', () =>
      HttpResponse.json({
        meta: { count: remaining.length, current_page: '1' },
        payload: remaining,
      }),
    ),
    http.delete('/api/v1/accounts/1/contacts/2', () => {
      deleted.push('2')
      remaining = [remaining[0]!]
      return new HttpResponse(null, { status: 200 })
    }),
  )
  await renderRoute('/app/contacts')
  await screen.findByText('Contato 1')
  const user = userEvent.setup()
  const toggles = screen.getAllByRole('button', { name: 'Edit contact details' })
  await user.click(toggles[0]!)
  await user.click(toggles[1]!)
  expect(toggles[0]).toHaveAttribute('aria-expanded', 'false')
  expect(screen.getAllByPlaceholderText('Enter the first name')).toHaveLength(1)
  await user.click(screen.getByRole('button', { name: 'Delete contact' }))
  await user.click(screen.getByRole('button', { name: 'Delete now' }))
  const dialog = screen.getByRole('dialog')
  expect(deleted).toHaveLength(0)
  await user.click(within(dialog).getByRole('button', { name: 'Cancel' }))
  expect(deleted).toHaveLength(0)
  await user.click(screen.getByRole('button', { name: 'Delete now' }))
  await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Yes, Delete' }))
  await waitFor(() => expect(screen.queryByText('Contato 2')).not.toBeInTheDocument())
  expect(deleted).toEqual(['2'])
})

test('agentes podem editar no card sem ver a exclusão', async () => {
  const profile = profileFixture()
  asSignedIn({
    ...profile,
    accounts: profile.accounts.map((account) => ({ ...account, role: 'agent' })),
  })
  respond([[contact(1)]])
  await renderRoute('/app/contacts')
  await screen.findByText('Contato 1')
  await userEvent.click(screen.getByRole('button', { name: 'Edit contact details' }))
  expect(screen.getByRole('button', { name: 'Update contact' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Delete contact' })).not.toBeInTheDocument()
})

test('falha ao salvar mantém a edição e informa e-mail duplicado', async () => {
  respond([[contact(1)]])
  server.use(
    http.put('/api/v1/accounts/1/contacts/1', () =>
      HttpResponse.json({ message: 'email has already been taken' }, { status: 422 }),
    ),
  )
  await renderRoute('/app/contacts')
  await screen.findByText('Contato 1')
  const user = userEvent.setup()
  await user.click(screen.getByRole('button', { name: 'Edit contact details' }))
  const email = screen.getByPlaceholderText('Enter the email address')
  await user.clear(email)
  await user.type(email, 'duplicate@acme.com')
  await user.click(screen.getByRole('button', { name: 'Update contact' }))
  expect(
    await screen.findByText('This email address is in use for another contact.'),
  ).toBeInTheDocument()
  expect(email).toHaveValue('duplicate@acme.com')
  expect(screen.getByText('Contato 1')).toBeInTheDocument()
})

test('"Tagged With" na sidebar lista os contatos com a etiqueta (#etiqueta no título)', async () => {
  respond([[contact(1, { name: 'Maria Billing' })]])
  server.use(
    http.get('/api/v1/accounts/1/labels', () =>
      HttpResponse.json({
        payload: [
          { id: 1, title: 'billing', description: null, color: '#ff0000', show_on_sidebar: true },
        ],
      }),
    ),
  )
  const user = userEvent.setup()
  const { router } = await renderRoute('/app/contacts')
  await screen.findByText('Maria Billing')

  await user.click(await screen.findByRole('button', { name: 'Tagged with' }))
  // "billing" também está em Labels (conversas): vale o link para os contatos
  const links = await screen.findAllByRole('link', { name: 'billing' })
  await user.click(links.find((link) => link.getAttribute('href')?.startsWith('/app/contacts'))!)
  await waitFor(() => expect(router.state.location.search).toMatchObject({ label: 'billing' }))
  expect(await screen.findByRole('heading', { name: '#billing' })).toBeInTheDocument()
  await waitFor(() => expect(requests.at(-1)!.searchParams.getAll('labels[]')).toEqual(['billing']))
  expect(requests.at(-1)!.searchParams.get('page')).toBe('1')
})
