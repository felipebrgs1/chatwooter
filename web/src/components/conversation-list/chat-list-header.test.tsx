import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { renderWithI18n } from '../../test/i18n'
import { ChatListHeader } from './chat-list-header'

const base = {
  title: 'Conversations',
  status: 'open' as const,
  sortBy: 'last_activity_at_desc' as const,
  onStatusChange: () => {},
  onSortChange: () => {},
}

test('mostra o título e o status atual', async () => {
  await renderWithI18n(<ChatListHeader {...base} />)
  expect(screen.getByRole('heading', { name: 'Conversations' })).toBeInTheDocument()
  expect(screen.getByTestId('chat-list-status')).toHaveTextContent('Open')
})

test('o menu de ordenação começa fechado e abre pelo botão', async () => {
  await renderWithI18n(<ChatListHeader {...base} />)
  expect(screen.queryByText('Order by')).not.toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Sort conversations' }))
  expect(screen.getByText('Order by')).toBeVisible()
  expect(screen.getByText('Status')).toBeVisible()
})

test('escolher um status avisa o pai e fecha a lista de opções', async () => {
  const onStatusChange = vi.fn()
  await renderWithI18n(<ChatListHeader {...base} onStatusChange={onStatusChange} />)
  await userEvent.click(screen.getByRole('button', { name: 'Sort conversations' }))
  await userEvent.click(screen.getByRole('button', { name: 'Open' }))
  const options = screen.getByRole('listbox', { name: 'Status' })
  await userEvent.click(within(options).getByRole('option', { name: 'Resolved' }))
  expect(onStatusChange).toHaveBeenCalledWith('resolved')
  expect(screen.queryByRole('listbox', { name: 'Status' })).not.toBeInTheDocument()
})

test('escolher a ordenação avisa o pai', async () => {
  const onSortChange = vi.fn()
  await renderWithI18n(<ChatListHeader {...base} onSortChange={onSortChange} />)
  await userEvent.click(screen.getByRole('button', { name: 'Sort conversations' }))
  await userEvent.click(screen.getByRole('button', { name: 'Last activity: Newest first' }))
  await userEvent.click(screen.getByRole('option', { name: 'Unread Count: Highest first' }))
  expect(onSortChange).toHaveBeenCalledWith('unread')
})

test('o opção selecionada fica marcada', async () => {
  await renderWithI18n(<ChatListHeader {...base} status="pending" />)
  await userEvent.click(screen.getByRole('button', { name: 'Sort conversations' }))
  await userEvent.click(screen.getByRole('button', { name: 'Pending' }))
  expect(screen.getByRole('option', { name: 'Pending' })).toHaveAttribute('aria-selected', 'true')
  expect(screen.getByRole('option', { name: 'Open' })).toHaveAttribute('aria-selected', 'false')
})
