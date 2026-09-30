import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import type { CustomFilter, FilterCondition } from '../../api/types'
import { contactFixture, conversationFixture } from '../../test/conversation-fixtures'
import { server } from '../../test/server'
import { Toaster } from '../toast/toaster'
import { ConversationList } from './conversation-list'
import { parseSearch, type ConversationsSearch } from './search'
import { renderWithApp } from './test-utils'

const statusOpen: FilterCondition = {
  attribute_key: 'status',
  filter_operator: 'equal_to',
  values: ['open'],
}

const folder = (overrides: Partial<CustomFilter> = {}): CustomFilter => ({
  id: 5,
  name: 'VIPs',
  filter_type: 'conversation',
  query: { payload: [{ attribute_key: 'labels', filter_operator: 'equal_to', values: ['vip'] }] },
  created_at: '2026-09-30T10:00:00.000Z',
  updated_at: '2026-09-30T10:00:00.000Z',
  ...overrides,
})

type Seen = { payload: FilterCondition[]; params: URLSearchParams }

function filterApi(seen: Seen[] = []) {
  server.use(
    http.post('/api/v1/accounts/1/conversations/filter', async ({ request }) => {
      const body = (await request.json()) as { payload: FilterCondition[] }
      seen.push({ payload: body.payload, params: new URL(request.url).searchParams })
      return HttpResponse.json({
        meta: { mine_count: 0, unassigned_count: 1, all_count: 2 },
        payload: [
          conversationFixture({
            id: 1,
            meta: {
              ...conversationFixture().meta,
              sender: contactFixture({ id: 1, name: 'Ana Souza' }),
            },
          }),
        ],
      })
    }),
  )
  return seen
}

function foldersApi(list: CustomFilter[]) {
  server.use(http.get('/api/v1/accounts/1/custom_filters', () => HttpResponse.json(list)))
}

const search = (overrides: Partial<ConversationsSearch> = {}) => ({
  ...parseSearch({}),
  ...overrides,
})

function list(overrides: Partial<ConversationsSearch>, onSearchChange = vi.fn()) {
  const view = renderWithApp(
    <>
      <ConversationList search={search(overrides)} onSearchChange={onSearchChange} />
      <Toaster />
    </>,
  )
  return { onSearchChange, view }
}

beforeEach(() => {
  vi.stubGlobal(
    'IntersectionObserver',
    class {
      observe() {}
      disconnect() {}
      unobserve() {}
    },
  )
})
afterEach(() => vi.unstubAllGlobals())

test('filtros aplicados vêm da URL: POST /filter, sem abas, com o total e o botão de voltar', async () => {
  const seen = filterApi()
  const { onSearchChange } = list({ filters: [statusOpen], sort_by: 'created_at_desc' })

  expect(await screen.findByRole('link', { name: /Ana Souza/ })).toBeInTheDocument()
  expect(seen[0].payload).toEqual([statusOpen])
  expect(seen[0].params.get('page')).toBe('1')
  expect(seen[0].params.get('sort_by')).toBe('created_at_desc')
  expect(screen.getByRole('heading', { level: 1, name: 'Conversations' })).toBeInTheDocument()
  expect(screen.queryByRole('tablist')).not.toBeInTheDocument()
  expect(screen.getByTitle('2')).toHaveTextContent('2')

  await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }))
  expect(onSearchChange).toHaveBeenCalledWith({ filters: undefined })
})

test('o botão de filtro abre o modal com o status atual e aplicar leva o filtro para a URL', async () => {
  server.use(
    http.get('/api/v1/accounts/1/conversations', () =>
      HttpResponse.json({
        data: {
          meta: { mine_count: 0, assigned_count: 0, unassigned_count: 0, all_count: 0 },
          payload: [],
        },
      }),
    ),
  )
  const user = userEvent.setup()
  const { onSearchChange } = list({ status: 'pending' })

  await user.click(await screen.findByRole('button', { name: 'Filter conversations' }))
  expect(screen.getByRole('heading', { name: 'Filter conversations' })).toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Apply filters' }))

  expect(onSearchChange).toHaveBeenCalledWith({
    filters: [{ attribute_key: 'status', filter_operator: 'equal_to', values: ['pending'] }],
    folder_id: undefined,
  })
  expect(screen.queryByRole('heading', { name: 'Filter conversations' })).not.toBeInTheDocument()
})

test('salvar o filtro cria a pasta, avisa e abre a pasta nova', async () => {
  filterApi()
  let created: unknown
  server.use(
    http.post('/api/v1/accounts/1/custom_filters', async ({ request }) => {
      created = await request.json()
      foldersApi([folder({ id: 9, name: 'Abertas' })])
      return HttpResponse.json(folder({ id: 9, name: 'Abertas' }))
    }),
  )
  const user = userEvent.setup()
  const { onSearchChange } = list({ filters: [statusOpen] })

  await user.click(await screen.findByRole('button', { name: 'Save filter' }))
  expect(
    screen.getByRole('heading', { name: 'Do you want to save this filter?' }),
  ).toBeInTheDocument()
  const submit = screen.getAllByRole('button', { name: 'Save filter' }).at(-1)!
  expect(submit).toBeDisabled()
  await user.type(screen.getByPlaceholderText('Name your filter to refer it later.'), 'Abertas')
  await user.click(submit)

  await waitFor(() =>
    expect(created).toEqual({
      custom_filter: { name: 'Abertas', filter_type: 0, query: { payload: [statusOpen] } },
    }),
  )
  expect(await screen.findByText('Folder created successfully.')).toBeInTheDocument()
  await waitFor(() =>
    expect(onSearchChange).toHaveBeenCalledWith(
      expect.objectContaining({ folder_id: 9, filters: undefined }),
    ),
  )
})

test('a pasta filtra pela query salva e mostra o nome, editar e excluir', async () => {
  foldersApi([folder()])
  const seen = filterApi()
  list({ folder_id: 5 })

  expect(await screen.findByRole('heading', { level: 1, name: 'VIPs' })).toBeInTheDocument()
  await screen.findByRole('link', { name: /Ana Souza/ })
  expect(seen[0].payload).toEqual(folder().query.payload)
  expect(screen.queryByRole('tablist')).not.toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Edit folder' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Delete filter' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Save filter' })).not.toBeInTheDocument()
})

test('editar a pasta atualiza nome e condições', async () => {
  foldersApi([folder()])
  filterApi()
  // a condição de etiqueta só volta para o modal se a etiqueta ainda existe na conta (getValuesForLabels)
  server.use(
    http.get('/api/v1/accounts/1/labels', () =>
      HttpResponse.json({
        payload: [
          { id: 1, title: 'vip', description: null, color: '#ff0000', show_on_sidebar: true },
        ],
      }),
    ),
  )
  let patched: unknown
  server.use(
    http.patch('/api/v1/accounts/1/custom_filters/5', async ({ request }) => {
      patched = await request.json()
      foldersApi([folder({ name: 'Só VIPs' })])
      return HttpResponse.json(folder({ name: 'Só VIPs' }))
    }),
  )
  const user = userEvent.setup()
  list({ folder_id: 5 })

  await user.click(await screen.findByRole('button', { name: 'Edit folder' }))
  const name = screen.getByLabelText('Folder Name')
  expect(name).toHaveValue('VIPs')
  await user.clear(name)
  await user.type(name, 'Só VIPs')
  await user.click(screen.getByRole('button', { name: 'Update folder' }))

  await waitFor(() =>
    expect(patched).toEqual({
      custom_filter: { name: 'Só VIPs', query: { payload: folder().query.payload } },
    }),
  )
  expect(await screen.findByRole('heading', { level: 1, name: 'Só VIPs' })).toBeInTheDocument()
})

test('excluir a pasta pede confirmação, avisa e volta para a lista quando não sobra pasta', async () => {
  foldersApi([folder()])
  filterApi()
  let deleted = false
  server.use(
    http.delete('/api/v1/accounts/1/custom_filters/5', () => {
      deleted = true
      foldersApi([])
      return new HttpResponse(null, { status: 204 })
    }),
  )
  const user = userEvent.setup()
  const { onSearchChange } = list({ folder_id: 5 })

  await user.click(await screen.findByRole('button', { name: 'Delete filter' }))
  const dialog = screen.getByRole('dialog', { name: 'Confirm deletion' })
  expect(within(dialog).getByText(/Are you sure to delete the filter\s+VIPs\?/)).toBeInTheDocument()
  await user.click(within(dialog).getByRole('button', { name: 'Yes, delete' }))

  await waitFor(() => expect(deleted).toBe(true))
  expect(await screen.findByText('Folder deleted successfully.')).toBeInTheDocument()
  await waitFor(() => expect(onSearchChange).toHaveBeenCalledWith({ folder_id: undefined }))
})
