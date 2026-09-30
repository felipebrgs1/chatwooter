import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { expect, test, vi } from 'vitest'
import { server } from '../../test/server'
import { renderWithApp } from '../conversation-list/test-utils'
import { CompanySelector } from './company-selector'

test('seleciona empresa existente e permite criar pelo nome buscado', async () => {
  const onSelect = vi.fn()
  server.use(
    http.get('/api/v1/accounts/1/companies', () =>
      HttpResponse.json({ meta: { total_count: 1, page: 1 }, payload: [{ id: 7, name: 'Acme' }] }),
    ),
    http.get('/api/v1/accounts/1/companies/search', () =>
      HttpResponse.json({ meta: { total_count: 0, page: 1 }, payload: [] }),
    ),
    http.post('/api/v1/accounts/1/companies', async ({ request }) => {
      const { company } = (await request.json()) as { company: { name: string } }
      return HttpResponse.json({ payload: { ...company, id: 8 } })
    }),
  )
  await renderWithApp(<CompanySelector value={null} selectedName="" onSelect={onSelect} />)
  const user = userEvent.setup()
  await user.click(screen.getByRole('button', { name: 'Select company' }))
  await user.click(await screen.findByRole('option', { name: 'Acme' }))
  expect(onSelect).toHaveBeenCalledWith({ id: 7, name: 'Acme' })
  await user.click(screen.getByRole('button', { name: 'Select company' }))
  await user.type(screen.getByPlaceholderText('Search companies...'), 'New company')
  await user.click(await screen.findByRole('option', { name: 'Add "New company"' }))
  const dialog = screen.getByRole('dialog')
  expect(within(dialog).getByRole('textbox', { name: 'Name' })).toHaveValue('New company')
  await user.click(within(dialog).getByRole('button', { name: 'Add company' }))
  await waitFor(() => expect(onSelect).toHaveBeenCalledWith({ id: 8, name: 'New company' }))
})
