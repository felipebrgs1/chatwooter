import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { beforeEach, expect, test } from 'vitest'

import type { ContactListItem, ContactNote } from '../../../../api/types'
import { contactFixture, conversationFixture } from '../../../../test/conversation-fixtures'
import { accountFixture, profileFixture } from '../../../../test/fixtures'
import { renderRoute } from '../../../../test/render'
import { server } from '../../../../test/server'
import { asSignedIn } from '../../../../test/session'

const BASE = '/api/v1/accounts/1/contacts/7'
let contact: ContactListItem
let labels: string[]
let notes: ContactNote[]
let calls: { method: string; path: string; body: unknown }[]

function record(method: string) {
  return async ({ request }: { request: Request }) => {
    const body =
      request.method === 'GET' || request.method === 'DELETE' ? null : await request.json()
    calls.push({ method, path: new URL(request.url).pathname, body })
    return body
  }
}

// a sidebar do app também lista as etiquetas: as buscas ficam na área do contato
const content = () => screen.getAllByRole('main').at(-1)!

beforeEach(() => {
  calls = []
  labels = ['vip']
  notes = []
  contact = contactFixture({
    id: 7,
    name: 'Carla Dias',
    email: 'carla@x.com',
    phone_number: '+5511988887777',
    identifier: 'crm-7',
    created_at: Math.floor(Date.now() / 1000) - 3 * 86400,
    last_activity_at: Math.floor(Date.now() / 1000) - 3600,
  })
  asSignedIn()
  server.use(
    http.get(BASE, () => HttpResponse.json({ payload: contact })),
    http.put(BASE, async (info) => {
      const body = (await record('PUT')(info)) as Partial<ContactListItem>
      contact = { ...contact, ...body }
      return HttpResponse.json({ payload: contact })
    }),
    http.delete(BASE, async (info) => {
      await record('DELETE')(info)
      return new HttpResponse(null, { status: 200 })
    }),
    http.get(`${BASE}/labels`, () => HttpResponse.json({ payload: labels })),
    http.post(`${BASE}/labels`, async (info) => {
      const body = (await record('POST')(info)) as { labels: string[] }
      labels = body.labels
      return HttpResponse.json({ payload: labels })
    }),
    http.get(`${BASE}/notes`, () => HttpResponse.json(notes)),
    http.post(`${BASE}/notes`, async (info) => {
      const body = (await record('POST')(info)) as { content: string }
      const note = { id: notes.length + 1, content: body.content, created_at: 1, updated_at: 1 }
      notes = [note, ...notes]
      return HttpResponse.json(note)
    }),
    http.delete(`${BASE}/notes/:noteId`, async (info) => {
      await record('DELETE')(info)
      notes = notes.filter((n) => n.id !== Number(info.params.noteId))
      return new HttpResponse(null, { status: 200 })
    }),
    http.get(`${BASE}/conversations`, () =>
      HttpResponse.json({
        payload: [
          conversationFixture({
            id: 31,
            meta: { ...conversationFixture().meta, sender: contactFixture({ name: 'Carla Dias' }) },
          }),
        ],
      }),
    ),
    http.get('/api/v1/accounts/1/labels', () =>
      HttpResponse.json({
        payload: [
          { id: 1, title: 'vip', description: null, color: '#00ff00', show_on_sidebar: true },
          { id: 2, title: 'lead', description: null, color: '#ff0000', show_on_sidebar: true },
        ],
      }),
    ),
  )
})

test('mostra o breadcrumb, o cabeçalho do contato e o formulário preenchido', async () => {
  await renderRoute('/app/contacts/7')
  expect(await screen.findByRole('heading', { level: 3, name: 'Carla Dias' })).toBeInTheDocument()
  const breadcrumb = screen.getByRole('navigation', { name: 'Breadcrumb' })
  expect(within(breadcrumb).getByRole('button', { name: 'Contacts' })).toBeInTheDocument()
  expect(within(breadcrumb).getByText('Carla Dias')).toBeInTheDocument()
  expect(screen.getByText('crm-7')).toBeInTheDocument()
  expect(screen.getByText('Created 3 days ago')).toBeInTheDocument()
  expect(screen.getByText('Last active about 1 hour ago')).toBeInTheDocument()
  expect(screen.getByPlaceholderText('Enter the first name')).toHaveValue('Carla')
  expect(screen.getByPlaceholderText('Enter the email address')).toHaveValue('carla@x.com')
  expect(await within(content()).findByText('vip')).toBeInTheDocument()
})

test('"Update contact" envia o formulário e avisa', async () => {
  await renderRoute('/app/contacts/7')
  const last = await screen.findByPlaceholderText('Enter the last name')
  await userEvent.clear(last)
  await userEvent.type(last, 'Souza')
  await userEvent.click(screen.getByRole('button', { name: 'Update contact' }))

  expect(await screen.findByText('Contact updated successfully')).toBeInTheDocument()
  const put = calls.find((c) => c.method === 'PUT')!
  expect(put.body).toMatchObject({ name: 'Carla Souza', email: 'carla@x.com' })
})

test('e-mail em uso mostra a mensagem de duplicado', async () => {
  server.use(
    http.put(BASE, () =>
      HttpResponse.json(
        { message: 'Email has already been taken', attributes: ['email'] },
        { status: 422 },
      ),
    ),
  )
  await renderRoute('/app/contacts/7')
  await userEvent.click(await screen.findByRole('button', { name: 'Update contact' }))
  await userEvent.type(screen.getByPlaceholderText('Enter the city name'), 'x')
  await userEvent.click(screen.getByRole('button', { name: 'Update contact' }))
  expect(
    await screen.findByText('This email address is in use for another contact.'),
  ).toBeInTheDocument()
})

test('bloquear e desbloquear pelo cabeçalho', async () => {
  await renderRoute('/app/contacts/7')
  await userEvent.click(await screen.findByRole('button', { name: 'Block contact' }))
  expect(await screen.findByRole('button', { name: 'Unblock contact' })).toBeInTheDocument()
  expect(calls.at(-1)).toMatchObject({ method: 'PUT', body: { blocked: true } })
})

test('adiciona e remove etiquetas', async () => {
  await renderRoute('/app/contacts/7')
  await within(content()).findByText('vip')
  await userEvent.click(screen.getByRole('button', { name: 'tag' }))
  await userEvent.click(within(content()).getByRole('button', { name: 'lead' }))
  await waitFor(() => expect(labels).toEqual(['vip', 'lead']))
  expect(await within(content()).findAllByText('lead')).not.toHaveLength(0)

  const vip = within(content()).getByText('vip').parentElement!
  await userEvent.hover(vip)
  await userEvent.click(within(vip).getByRole('button'))
  await waitFor(() => expect(labels).toEqual(['lead']))
})

test('o admin exclui o contato após confirmar e volta à lista', async () => {
  server.use(
    http.get('/api/v1/accounts/1/contacts', () =>
      HttpResponse.json({ meta: { count: 0, current_page: '1' }, payload: [] }),
    ),
  )
  const { router } = await renderRoute('/app/contacts/7')
  await userEvent.click(await screen.findByRole('button', { name: 'Delete contact' }))
  await userEvent.click(screen.getByRole('button', { name: 'Yes, Delete' }))
  await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true))
  await waitFor(() => expect(router.state.location.pathname).toBe('/app/contacts'))
  expect(await screen.findByText('Contact deleted successfully')).toBeInTheDocument()
})

test('agente não vê a exclusão', async () => {
  asSignedIn(
    profileFixture({ accounts: [accountFixture({ role: 'agent', permissions: ['agent'] })] }),
  )
  await renderRoute('/app/contacts/7')
  await screen.findByRole('heading', { level: 3, name: 'Carla Dias' })
  expect(screen.queryByRole('button', { name: 'Delete contact' })).not.toBeInTheDocument()
})

test('aba History lista as conversas do contato', async () => {
  await renderRoute('/app/contacts/7')
  await userEvent.click(await screen.findByRole('tab', { name: 'History' }))
  const link = await screen.findByRole('link', { name: /Carla Dias/ })
  expect(link).toHaveAttribute('href', '/app/conversations/31')
})

test('aba Notes cria e apaga notas', async () => {
  await renderRoute('/app/contacts/7')
  await userEvent.click(await screen.findByRole('tab', { name: 'Notes' }))
  expect(
    await screen.findByText(/There are no notes associated to this contact/),
  ).toBeInTheDocument()

  await userEvent.type(screen.getByRole('textbox', { name: 'Add a note' }), 'Ligar amanhã')
  await userEvent.click(screen.getByRole('button', { name: 'Save note' }))
  expect(await screen.findByText('Ligar amanhã')).toBeInTheDocument()
  expect(calls.find((c) => c.path.endsWith('/notes'))!.body).toEqual({ content: 'Ligar amanhã' })

  const note = screen.getByText('Ligar amanhã').closest('article')!
  await userEvent.click(within(note).getByRole('button'))
  await waitFor(() => expect(screen.queryByText('Ligar amanhã')).not.toBeInTheDocument())
})
