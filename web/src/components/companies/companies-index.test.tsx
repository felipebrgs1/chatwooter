import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { beforeEach, expect, test, vi } from 'vitest'

import { server } from '../../test/server'
import { renderWithApp } from '../conversation-list/test-utils'
import { CompaniesIndex } from './companies-index'

const company = {
  id: 7,
  name: 'Acme',
  domain: 'acme.example',
  description: 'Support',
  contacts_count: 2,
  custom_attributes: {},
  avatar_url: '',
  created_at: 1790000000,
  updated_at: 1790000000,
}

beforeEach(() => {
  server.use(
    http.get('/api/v1/accounts/1/companies', () =>
      HttpResponse.json({ meta: { total_count: 26, page: '1' }, payload: [company] }),
    ),
  )
})

function list(props = {}) {
  return renderWithApp(
    <CompaniesIndex page={1} search="" onNavigate={() => {}} onShowCompany={() => {}} {...props} />,
  )
}

test('lista mostra domínio, total de contatos, paginação e abre o detalhe', async () => {
  const onShowCompany = vi.fn()
  await list({ onShowCompany })
  expect(await screen.findByText('acme.example')).toBeInTheDocument()
  expect(screen.getByText('2 contacts')).toBeInTheDocument()
  expect(screen.getByText('Showing 1 – 25 of 26 companies')).toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: /Acme/ }))
  expect(onShowCompany).toHaveBeenCalledExactlyOnceWith(7)
})

test('busca espera 300ms e reinicia a página na URL', async () => {
  const onNavigate = vi.fn()
  await list({ page: 2, onNavigate })
  await userEvent.type(screen.getByRole('searchbox', { name: 'Search companies...' }), 'Acme')
  await waitFor(() =>
    expect(onNavigate).toHaveBeenLastCalledWith({ page: 1, search: 'Acme', sort: 'name' }),
  )
})

test('URL de busca usa search e mantém paginação/ordenação', async () => {
  const requests: string[] = []
  server.use(
    http.get('/api/v1/accounts/1/companies/search', ({ request }) => {
      requests.push(request.url)
      return HttpResponse.json({ meta: { total_count: 1, page: '2' }, payload: [company] })
    }),
  )
  await list({ page: 2, search: 'Acme', sort: '-domain' })
  await screen.findByText('Acme')
  const params = new URL(requests[0]).searchParams
  expect(Object.fromEntries(params)).toEqual({ page: '2', q: 'Acme', sort: '-domain' })
})

test('cria empresa com dados aparados e abre o detalhe após sucesso', async () => {
  let body: unknown
  server.use(
    http.post('/api/v1/accounts/1/companies', async ({ request }) => {
      body = await request.json()
      return HttpResponse.json({ payload: company })
    }),
  )
  const onShowCompany = vi.fn()
  await list({ onShowCompany })
  await userEvent.click(screen.getByRole('button', { name: 'More actions' }))
  await userEvent.click(screen.getByRole('button', { name: 'Add company' }))
  const dialog = screen.getByRole('dialog')
  const save = within(dialog).getByRole('button', { name: 'Add company' })
  expect(save).toBeDisabled()
  await userEvent.type(within(dialog).getByRole('textbox', { name: 'Name' }), ' Acme ')
  await userEvent.type(within(dialog).getByRole('textbox', { name: 'Domain' }), ' acme.example ')
  await userEvent.click(save)
  await waitFor(() => expect(onShowCompany).toHaveBeenCalledExactlyOnceWith(7))
  expect(body).toEqual({ company: { name: 'Acme', domain: 'acme.example', description: null } })
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})

test('falha de criação mantém formulário aberto e permite tentar novamente', async () => {
  server.use(
    http.post('/api/v1/accounts/1/companies', () =>
      HttpResponse.json({ message: 'invalid' }, { status: 422 }),
    ),
  )
  await list()
  await userEvent.click(screen.getByRole('button', { name: 'More actions' }))
  await userEvent.click(screen.getByRole('button', { name: 'Add company' }))
  await userEvent.type(screen.getByRole('textbox', { name: 'Name' }), 'Acme')
  await userEvent.click(
    within(screen.getByRole('dialog')).getByRole('button', { name: 'Add company' }),
  )
  expect(await screen.findByRole('alert')).toHaveTextContent('Could not create the company.')
  expect(screen.getByRole('textbox', { name: 'Name' })).toHaveValue('Acme')
})

test('lista vazia usa o texto do Chatwoot', async () => {
  server.use(
    http.get('/api/v1/accounts/1/companies', () =>
      HttpResponse.json({ meta: { total_count: 0, page: 1 }, payload: [] }),
    ),
  )
  await list()
  expect(await screen.findByText('No companies found')).toBeInTheDocument()
})

test('erro da API não é apresentado como lista vazia', async () => {
  server.use(http.get('/api/v1/accounts/1/companies', () => HttpResponse.json({}, { status: 500 })))
  await list()
  expect(await screen.findByRole('alert')).toHaveTextContent(
    'Something went wrong. Please try again.',
  )
  expect(screen.queryByText('No companies found')).not.toBeInTheDocument()
})
