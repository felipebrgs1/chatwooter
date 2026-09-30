import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { contactFixture } from '../../test/conversation-fixtures'
import { renderWithApp } from '../conversation-list/test-utils'
import { ContactsForm } from './contacts-form'

const contact = contactFixture({
  id: 5,
  name: 'Mary Jane Smith',
  email: 'mary@x.com',
  phone_number: '+5511999990000',
  additional_attributes: {
    city: 'Recife',
    country_code: 'BR',
    country: 'Brazil',
    company_name: 'Acme',
    description: 'Cliente antiga',
    social_profiles: { github: 'mary' },
    social_whatsapp_user_name: '@@mary_wa',
  },
})

test('preenche os campos a partir do contato (nome dividido como o splitName)', async () => {
  await renderWithApp(<ContactsForm contact={contact} onChange={() => {}} />)
  expect(screen.getByPlaceholderText('Enter the first name')).toHaveValue('Mary Jane')
  expect(screen.getByPlaceholderText('Enter the last name')).toHaveValue('Smith')
  expect(screen.getByPlaceholderText('Enter the email address')).toHaveValue('mary@x.com')
  expect(screen.getByPlaceholderText('Enter the phone number')).toHaveValue('11999990000')
  expect(screen.getByPlaceholderText('Enter the city name')).toHaveValue('Recife')
  expect(screen.getByPlaceholderText('Enter the bio')).toHaveValue('Cliente antiga')
  expect(screen.getByRole('button', { name: 'Acme' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: /Brazil/ })).toBeInTheDocument()
  expect(screen.getByPlaceholderText('Add Github')).toHaveValue('mary')
  // o usuário do WhatsApp perde os @ do começo
  expect(screen.getByPlaceholderText('Add WhatsApp')).toHaveValue('mary_wa')
})

test('editar o nome junta nome e sobrenome e avisa o pai', async () => {
  const onChange = vi.fn()
  await renderWithApp(<ContactsForm contact={contact} onChange={onChange} />)
  const last = screen.getByPlaceholderText('Enter the last name')
  await userEvent.clear(last)
  await userEvent.type(last, 'Watson')
  const [data, invalid] = onChange.mock.lastCall!
  expect(data.name).toBe('Mary Jane Watson')
  expect(data).not.toHaveProperty('firstName')
  expect(data.additional_attributes.city).toBe('Recife')
  expect(invalid).toBe(false)
})

test('nome vazio ou e-mail inválido deixam o formulário inválido', async () => {
  const onChange = vi.fn()
  await renderWithApp(<ContactsForm contact={contact} onChange={onChange} />)
  const email = screen.getByPlaceholderText('Enter the email address')
  await userEvent.clear(email)
  await userEvent.type(email, 'nao-e-email')
  expect(onChange.mock.lastCall![1]).toBe(true)
  expect(email).toHaveAttribute('aria-invalid', 'true')

  await userEvent.clear(email)
  await userEvent.clear(screen.getByPlaceholderText('Enter the first name'))
  expect(onChange.mock.lastCall![1]).toBe(true)
})

test('escolher o país grava o código e o nome', async () => {
  const onChange = vi.fn()
  await renderWithApp(<ContactsForm contact={contact} onChange={onChange} />)
  await userEvent.click(screen.getByRole('button', { name: /Brazil/ }))
  await userEvent.type(screen.getByPlaceholderText('Search...'), 'Portugal')
  await userEvent.click(screen.getByRole('option', { name: 'Portugal' }))
  const [data] = onChange.mock.lastCall!
  expect(data.additional_attributes).toMatchObject({ country_code: 'PT', country: 'Portugal' })
})
