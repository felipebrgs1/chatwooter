import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { renderWithI18n } from '../../test/i18n'
import { ChatTypeTabs } from './chat-type-tabs'

const counts = { mine_count: 3, assigned_count: 5, unassigned_count: 2, all_count: 7 }

test('mostra as três abas com seus contadores', async () => {
  await renderWithI18n(<ChatTypeTabs active="me" counts={counts} onChange={() => {}} />)
  expect(screen.getByRole('tab', { name: 'Mine 3' })).toHaveAttribute('aria-selected', 'true')
  expect(screen.getByRole('tab', { name: 'Unassigned 2' })).toHaveAttribute(
    'aria-selected',
    'false',
  )
  expect(screen.getByRole('tab', { name: 'All 7' })).toBeInTheDocument()
})

test('clicar numa aba avisa qual foi escolhida', async () => {
  const onChange = vi.fn()
  await renderWithI18n(<ChatTypeTabs active="me" counts={counts} onChange={onChange} />)
  await userEvent.click(screen.getByRole('tab', { name: /Unassigned/ }))
  expect(onChange).toHaveBeenCalledWith('unassigned')
})

test('sem contadores ainda mostra zero', async () => {
  await renderWithI18n(<ChatTypeTabs active="all" counts={undefined} onChange={() => {}} />)
  expect(screen.getByRole('tab', { name: 'All 0' })).toBeInTheDocument()
})
