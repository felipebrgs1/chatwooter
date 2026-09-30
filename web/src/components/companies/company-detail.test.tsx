import { screen } from '@testing-library/react'
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
