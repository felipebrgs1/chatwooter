import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test } from 'vitest'

import { SearchableList } from './searchable-list'

const items = [
  { value: 'g', label: 'Grupo', header: true },
  { value: 'a', label: 'Ana' },
  { value: 'b', label: 'Bruno' },
]

function Demo() {
  return (
    <SearchableList items={items} getText={(i) => i.label} isHeader={(i) => i.header === true}>
      {({ query, setQuery, visible, isEmpty }) => (
        <div>
          <input type="search" value={query} onChange={(e) => setQuery(e.target.value)} />
          <ul>
            {visible.map((i) => (
              <li key={i.value}>{i.label}</li>
            ))}
          </ul>
          {isEmpty && <p>vazio</p>}
        </div>
      )}
    </SearchableList>
  )
}

test('sem busca mostra tudo, cabeçalhos inclusive', () => {
  render(<Demo />)
  expect(screen.getAllByRole('listitem')).toHaveLength(3)
})

test('filtra ignorando caixa e esconde cabeçalhos', async () => {
  render(<Demo />)
  await userEvent.type(screen.getByRole('searchbox'), 'BRU')
  expect(screen.getAllByRole('listitem').map((li) => li.textContent)).toEqual(['Bruno'])
})

test('sem resultado avisa', async () => {
  render(<Demo />)
  await userEvent.type(screen.getByRole('searchbox'), 'zzz')
  expect(screen.getByText('vazio')).toBeInTheDocument()
})
