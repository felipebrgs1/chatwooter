import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { expect, test, vi } from 'vitest'

import { server } from '../../test/server'
import { renderWithApp } from '../conversation-list/test-utils'
import { CompanyDetail } from './company-detail'

test('detalhe lê a empresa da conta e volta para a lista', async () => {
  server.use(
    http.get('/api/v1/accounts/1/companies/7', () =>
      HttpResponse.json({
        payload: {
          id: 7,
          name: 'Acme',
          domain: 'acme.example',
          description: 'Support',
          avatar_url: '',
          contacts_count: null,
          custom_attributes: {},
          created_at: 1790000000,
          updated_at: 1790000000,
        },
      }),
    ),
  )
  const onBack = vi.fn()
  await renderWithApp(<CompanyDetail companyId={7} onBack={onBack} />)
  expect(await screen.findByRole('textbox', { name: 'Name' })).toHaveValue('Acme')
  expect(screen.getByRole('textbox', { name: 'Domain' })).toHaveValue('acme.example')
  expect(
    screen.getByRole('textbox', { name: 'Add a short description for this company' }),
  ).toHaveValue('Support')
  await userEvent.click(screen.getByRole('button', { name: 'Companies' }))
  expect(onBack).toHaveBeenCalledOnce()
})

test('falha do servidor não é apresentada como empresa inexistente', async () => {
  server.use(
    http.get('/api/v1/accounts/1/companies/7', () => HttpResponse.json({}, { status: 500 })),
  )
  await renderWithApp(<CompanyDetail companyId={7} onBack={() => {}} />)
  expect(await screen.findByRole('alert')).toHaveTextContent(
    'Something went wrong. Please try again.',
  )
  expect(screen.queryByText('Company not found')).not.toBeInTheDocument()
})

test('empresa ausente mostra o estado de não encontrada', async () => {
  server.use(
    http.get('/api/v1/accounts/1/companies/99', () =>
      HttpResponse.json({ error: 'not found' }, { status: 404 }),
    ),
  )
  await renderWithApp(<CompanyDetail companyId={99} onBack={() => {}} />)
  expect(await screen.findByText('Company not found')).toBeInTheDocument()
})

test('edita os dados da empresa, valida nome e salva pela API', async () => {
  let company = {
    id: 7,
    name: 'Acme',
    domain: 'acme.example',
    description: 'Support',
    avatar_url: '',
    contacts_count: null,
    custom_attributes: {},
    created_at: 1790000000,
    updated_at: 1790000000,
  }
  server.use(
    http.get('/api/v1/accounts/1/companies/7', () => HttpResponse.json({ payload: company })),
    http.put('/api/v1/accounts/1/companies/7', async ({ request }) => {
      const body = (await request.json()) as { company: typeof company }
      company = { ...company, ...body.company }
      return HttpResponse.json({ payload: company })
    }),
  )
  await renderWithApp(<CompanyDetail companyId={7} onBack={() => {}} />)
  const name = await screen.findByRole('textbox', { name: 'Name' })
  const user = userEvent.setup()
  const save = screen.getByRole('button', { name: 'Update company' })
  expect(save).toBeDisabled()
  await user.clear(name)
  expect(save).toBeDisabled()
  await user.type(name, 'Updated')
  await user.click(save)
  await waitFor(() => expect(company.name).toBe('Updated'))
  expect(save).toBeDisabled()
})

test('exclusão exige confirmação e volta à lista após sucesso', async () => {
  const remove = vi.fn()
  const onBack = vi.fn()
  server.use(
    http.get('/api/v1/accounts/1/companies/7', () =>
      HttpResponse.json({
        payload: {
          id: 7,
          name: 'Acme',
          domain: null,
          description: null,
          avatar_url: '',
          created_at: 1790000000,
        },
      }),
    ),
    http.delete('/api/v1/accounts/1/companies/7', () => {
      remove()
      return new HttpResponse(null, { status: 200 })
    }),
  )
  await renderWithApp(<CompanyDetail companyId={7} onBack={onBack} />)
  await screen.findByRole('textbox', { name: 'Name' })
  const user = userEvent.setup()
  await user.click(screen.getByRole('button', { name: 'Delete company' }))
  expect(screen.getByRole('dialog')).toHaveTextContent(
    'This will remove Acme and unlink all associated contacts.',
  )
  expect(remove).not.toHaveBeenCalled()
  await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Cancel' }))
  expect(remove).not.toHaveBeenCalled()
  await user.click(screen.getByRole('button', { name: 'Delete company' }))
  await user.click(
    within(screen.getByRole('dialog')).getByRole('button', { name: 'Delete company' }),
  )
  await waitFor(() => expect(onBack).toHaveBeenCalledOnce())
  expect(remove).toHaveBeenCalledOnce()
})

test('falha ao salvar restaura os dados e falha ao excluir mantém o detalhe', async () => {
  const onBack = vi.fn()
  server.use(
    http.get('/api/v1/accounts/1/companies/7', () =>
      HttpResponse.json({
        payload: {
          id: 7,
          name: 'Acme',
          domain: null,
          description: null,
          avatar_url: '',
          created_at: 1790000000,
        },
      }),
    ),
    http.put('/api/v1/accounts/1/companies/7', () =>
      HttpResponse.json({ message: 'Domain is invalid' }, { status: 422 }),
    ),
    http.delete('/api/v1/accounts/1/companies/7', () => HttpResponse.json({}, { status: 500 })),
  )
  await renderWithApp(<CompanyDetail companyId={7} onBack={onBack} />)
  const name = await screen.findByRole('textbox', { name: 'Name' })
  const user = userEvent.setup()
  await user.clear(name)
  await user.type(name, 'Unsaved')
  await user.click(screen.getByRole('button', { name: 'Update company' }))
  await waitFor(() => expect(name).toHaveValue('Acme'))
  await user.click(screen.getByRole('button', { name: 'Delete company' }))
  await user.click(
    within(screen.getByRole('dialog')).getByRole('button', { name: 'Delete company' }),
  )
  await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
  expect(onBack).not.toHaveBeenCalled()
  expect(name).toHaveValue('Acme')
})

test('abas de contatos, histórico e notas mostram os dados vinculados', async () => {
  server.use(
    http.get('/api/v1/accounts/1/companies/7', () =>
      HttpResponse.json({
        payload: {
          id: 7,
          name: 'Acme',
          domain: null,
          description: null,
          avatar_url: '',
          created_at: 1790000000,
        },
      }),
    ),
    http.get('/api/v1/accounts/1/companies/7/contacts', () =>
      HttpResponse.json({
        meta: { total_count: 1, page: 1 },
        payload: [
          {
            id: 9,
            name: 'Linked contact',
            email: 'linked@acme.com',
            phone_number: null,
            company_id: 7,
          },
        ],
      }),
    ),
    http.get('/api/v1/accounts/1/companies/7/conversations', () =>
      HttpResponse.json({ payload: [] }),
    ),
    http.get('/api/v1/accounts/1/companies/7/notes', () =>
      HttpResponse.json({
        payload: [
          {
            id: 3,
            content: 'Company note',
            contact: { id: 9, name: 'Linked contact' },
            user: { id: 1, name: 'John' },
            created_at: 1790000000,
          },
        ],
      }),
    ),
  )
  await renderWithApp(<CompanyDetail companyId={7} onBack={() => {}} />)
  const user = userEvent.setup()
  await user.click(await screen.findByRole('tab', { name: 'Contacts' }))
  expect(await screen.findByText('linked@acme.com')).toBeInTheDocument()
  await user.click(screen.getByRole('tab', { name: 'History' }))
  expect(
    await screen.findByText("No conversations found for this company's contacts yet."),
  ).toBeInTheDocument()
  await user.click(screen.getByRole('tab', { name: 'Notes' }))
  expect(await screen.findByText('Company note')).toBeInTheDocument()
})

test('upload do avatar usa multipart e atualiza a imagem', async () => {
  let company = {
    id: 7,
    name: 'Acme',
    domain: null,
    description: null,
    avatar_url: '',
    created_at: 1790000000,
  }
  let uploaded = ''
  server.use(
    http.get('/api/v1/accounts/1/companies/7', () => HttpResponse.json({ payload: company })),
    http.put('/api/v1/accounts/1/companies/7', async ({ request }) => {
      uploaded = await request.text()
      company = { ...company, avatar_url: '/api/v1/accounts/1/companies/7/avatar?version=1' }
      return HttpResponse.json({ payload: company })
    }),
  )
  await renderWithApp(<CompanyDetail companyId={7} onBack={() => {}} />)
  const input = await screen.findByLabelText('Profile Image')
  await userEvent.upload(input, new File(['png'], 'logo.png', { type: 'image/png' }))
  await waitFor(() => expect(uploaded).toContain('name="company[avatar]"'))
  expect(await screen.findByRole('button', { name: 'Delete Avatar' })).toBeInTheDocument()
})
