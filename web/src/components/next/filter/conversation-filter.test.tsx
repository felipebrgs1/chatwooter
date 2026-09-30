import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { beforeEach, expect, test, vi } from 'vitest'

import { renderWithApp } from '../../conversation-list/test-utils'
import { server } from '../../../test/server'
import { ConversationFilter } from './conversation-filter'
import type { FilterRow } from './filter-query'

beforeEach(() => {
  server.use(
    http.get('/api/v1/accounts/:id/labels', () =>
      HttpResponse.json({
        payload: [
          { id: 1, title: 'vip', description: null, color: '#ff0000', show_on_sidebar: true },
        ],
      }),
    ),
  )
})

const statusOpen: FilterRow = {
  attribute_key: 'status',
  filter_operator: 'equal_to',
  values: [{ id: 'open', name: 'Open' }],
  query_operator: 'and',
}

function open(props: Partial<React.ComponentProps<typeof ConversationFilter>> = {}) {
  const handlers = { onApply: vi.fn(), onClose: vi.fn(), onUpdateFolder: vi.fn() }
  return {
    ...handlers,
    view: renderWithApp(
      <ConversationFilter initialFilters={[statusOpen]} {...handlers} {...props} />,
    ),
  }
}

test('mostra as condições iniciais e aplica o filtro', async () => {
  const { onApply } = open()
  expect(await screen.findByRole('heading', { name: 'Filter conversations' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Status' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Equal to' })).toBeInTheDocument()

  await userEvent.click(screen.getByRole('button', { name: 'Apply filters' }))
  expect(onApply).toHaveBeenCalledWith([statusOpen])
})

test('sem valor, não aplica e avisa na linha', async () => {
  const { onApply } = open({ initialFilters: [{ ...statusOpen, values: [] }] })
  await userEvent.click(await screen.findByRole('button', { name: 'Apply filters' }))
  expect(screen.getByText('Value is required')).toBeInTheDocument()
  expect(onApply).not.toHaveBeenCalled()
})

test('adicionar condição traz o AND, que pode virar OR, e trocar o atributo zera valor e operador', async () => {
  const user = userEvent.setup()
  const { onApply } = open()
  await user.click(await screen.findByRole('button', { name: 'Add filter' }))
  const rows = screen
    .getAllByRole('listitem')
    .filter((li) => li.closest('ul[data-filter-conditions]'))
  expect(rows).toHaveLength(2)

  const second = rows[1]
  await user.click(within(second).getByRole('button', { name: 'AND' }))
  await user.click(screen.getByRole('button', { name: 'OR' }))

  await user.click(within(second).getByRole('button', { name: 'Status' }))
  await user.click(screen.getByRole('button', { name: 'Labels' }))
  await user.click(within(second).getByRole('button', { name: 'Select an option...' }))
  await user.click(await screen.findByRole('button', { name: 'vip' }))

  await user.click(screen.getByRole('button', { name: 'Apply filters' }))
  expect(onApply).toHaveBeenCalledWith([
    { ...statusOpen, query_operator: 'or' },
    {
      attribute_key: 'labels',
      filter_operator: 'equal_to',
      values: [{ id: 'vip', name: 'vip' }],
      query_operator: 'and',
    },
  ])
})

test('operador de presença não pede valor', async () => {
  const user = userEvent.setup()
  const { onApply } = open({
    initialFilters: [
      {
        attribute_key: 'assignee_id',
        filter_operator: 'equal_to',
        values: {},
        query_operator: 'and',
      },
    ],
  })
  await user.click(await screen.findByRole('button', { name: 'Equal to' }))
  await user.click(screen.getByRole('button', { name: 'Is not present' }))
  expect(screen.queryByRole('button', { name: 'Select an option...' })).not.toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Apply filters' }))
  expect(onApply).toHaveBeenCalledWith([
    expect.objectContaining({ attribute_key: 'assignee_id', filter_operator: 'is_not_present' }),
  ])
})

test('limpar volta para uma condição padrão, e remover a única também', async () => {
  const user = userEvent.setup()
  open()
  await user.click(await screen.findByRole('button', { name: 'Add filter' }))
  await user.click(screen.getByRole('button', { name: 'Clear filters' }))
  expect(screen.getAllByRole('button', { name: 'Status' })).toHaveLength(1)
  expect(screen.getByRole('button', { name: 'Select an option...' })).toBeInTheDocument()
})

test('na pasta, edita o nome e atualiza', async () => {
  const user = userEvent.setup()
  const { onUpdateFolder, onApply } = open({ isFolderView: true, folderName: 'VIPs' })
  expect(await screen.findByRole('heading', { name: 'Edit Folder' })).toBeInTheDocument()
  const name = screen.getByLabelText('Folder Name')
  await user.clear(name)
  expect(screen.getByRole('button', { name: 'Update folder' })).toBeDisabled()
  await user.type(name, 'Só VIPs')
  await user.click(screen.getByRole('button', { name: 'Update folder' }))
  expect(onUpdateFolder).toHaveBeenCalledWith([statusOpen], 'Só VIPs')
  expect(onApply).not.toHaveBeenCalled()
})

test('Esc ou clique fora fecha', async () => {
  const user = userEvent.setup()
  const { onClose } = open()
  await screen.findByRole('heading', { name: 'Filter conversations' })
  await user.click(document.body)
  expect(onClose).toHaveBeenCalled()
})
