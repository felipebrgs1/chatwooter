import { render, screen } from '@testing-library/react'
import { expect, test } from 'vitest'

import { Breadcrumb } from './breadcrumb'

const items = [
  { label: 'Contatos', href: '/app/contacts' },
  { label: 'Empresas', href: '/app/companies' },
  { label: 'Acme' },
]

test('todos menos o último são links; o último é o texto atual', () => {
  render(<Breadcrumb ariaLabel="Trilha" items={items} />)
  expect(screen.getByRole('navigation', { name: 'Trilha' })).toBeInTheDocument()
  expect(screen.getByRole('link', { name: 'Contatos' })).toHaveAttribute('href', '/app/contacts')
  expect(screen.getByRole('link', { name: 'Empresas' })).toBeInTheDocument()
  expect(screen.queryByRole('link', { name: 'Acme' })).not.toBeInTheDocument()
  expect(screen.getByText('Acme').closest('[aria-current]')).toHaveAttribute('aria-current', 'page')
})
