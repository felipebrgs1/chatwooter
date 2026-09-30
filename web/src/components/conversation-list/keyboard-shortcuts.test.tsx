import { fireEvent, screen } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { beforeEach, expect, test, vi } from 'vitest'

import { contactFixture, conversationFixture } from '../../test/conversation-fixtures'
import { server } from '../../test/server'
import { ConversationList } from './conversation-list'
import { parseSearch } from './search'
import { renderWithApp } from './test-utils'

beforeEach(() => {
  server.use(
    http.get('/api/v1/accounts/1/conversations', () =>
      HttpResponse.json({
        data: {
          meta: { mine_count: 3, assigned_count: 0, unassigned_count: 3, all_count: 3 },
          payload: [1, 2, 3].map((id) =>
            conversationFixture({
              id,
              meta: {
                ...conversationFixture().meta,
                sender: contactFixture({ name: `Cliente ${id}` }),
              },
            }),
          ),
        },
      }),
    ),
  )
})

async function list(activeId?: number, expanded = false) {
  const open = vi.fn()
  const result = await renderWithApp(
    <ConversationList
      search={parseSearch({ status: 'pending', label: 'vip' })}
      activeId={activeId}
      expanded={expanded}
      onSearchChange={() => {}}
      renderCardLink={(conversation, props) => (
        <a
          {...props}
          href={`/app/conversations/${conversation.id}?status=pending&label=vip`}
          onClick={(event) => {
            event.preventDefault()
            open(conversation.id)
          }}
        />
      )}
    />,
  )
  await screen.findByRole('link', { name: /Cliente 3/ })
  return { ...result, open }
}

function shortcut(code: string, target: Document | HTMLElement = document, modifiers = {}) {
  fireEvent.keyDown(target, { code, altKey: true, ...modifiers })
}

test.each([
  [2, 'KeyJ', 1],
  [2, 'KeyK', 3],
  [1, 'KeyJ', 1],
  [3, 'KeyK', 3],
  [undefined, 'KeyJ', 1],
  [undefined, 'KeyK', 1],
])('conversa %s + %s abre %s sem dar a volta na lista', async (activeId, code, expected) => {
  const { open } = await list(activeId)
  shortcut(code)
  expect(open).toHaveBeenCalledExactlyOnceWith(expected)
  expect(screen.getByRole('link', { name: new RegExp(`Cliente ${expected}`) })).toHaveAttribute(
    'href',
    `/app/conversations/${expected}?status=pending&label=vip`,
  )
})

test('navega também no layout expandido', async () => {
  const { open } = await list(2, true)
  shortcut('KeyK')
  expect(open).toHaveBeenCalledExactlyOnceWith(3)
})

test('J/K funcionam com o foco no composer; outros modificadores não acionam', async () => {
  const { open, unmount } = await list(2)
  const input = document.createElement('textarea')
  document.body.append(input)
  try {
    shortcut('KeyJ', input)
    expect(open).toHaveBeenCalledExactlyOnceWith(1)
    open.mockClear()
    shortcut('KeyK', input, { ctrlKey: true })
    shortcut('KeyK', input, { metaKey: true })
    shortcut('KeyK', input, { shiftKey: true })
    shortcut('KeyK', input, { altKey: false })
    expect(open).not.toHaveBeenCalled()
    unmount()
    shortcut('KeyK', input)
    expect(open).not.toHaveBeenCalled()
  } finally {
    input.remove()
  }
})

test.each([
  ['me', 'unassigned'],
  ['unassigned', 'all'],
  ['all', 'me'],
] as const)('Alt+N alterna de %s para %s', async (active, next) => {
  const onSearchChange = vi.fn()
  await renderWithApp(
    <ConversationList
      search={parseSearch({ assignee_type: active })}
      onSearchChange={onSearchChange}
    />,
  )
  shortcut('KeyN')
  expect(onSearchChange).toHaveBeenCalledExactlyOnceWith({ assignee_type: next })
})

test.each(['input', 'textarea', 'div'])(
  'Alt+N não troca a aba enquanto digita em %s',
  async (tag) => {
    const onSearchChange = vi.fn()
    await renderWithApp(
      <ConversationList search={parseSearch({})} onSearchChange={onSearchChange} />,
    )
    const input = document.createElement(tag)
    if (tag === 'div') input.setAttribute('contenteditable', 'true')
    document.body.append(input)
    try {
      shortcut('KeyN', input)
      expect(onSearchChange).not.toHaveBeenCalled()
    } finally {
      input.remove()
    }
  },
)

test('Alt+N acompanha a aba atual após rerender e remove o listener ao desmontar', async () => {
  const onSearchChange = vi.fn()
  const { rerender, unmount } = await renderWithApp(
    <ConversationList
      search={parseSearch({ assignee_type: 'me' })}
      onSearchChange={onSearchChange}
    />,
  )
  shortcut('KeyN')
  expect(onSearchChange).toHaveBeenLastCalledWith({ assignee_type: 'unassigned' })
  rerender(
    <ConversationList
      search={parseSearch({ assignee_type: 'unassigned' })}
      onSearchChange={onSearchChange}
    />,
  )
  shortcut('KeyN')
  expect(onSearchChange).toHaveBeenLastCalledWith({ assignee_type: 'all' })
  expect(onSearchChange).toHaveBeenCalledTimes(2)
  unmount()
  shortcut('KeyN')
  expect(onSearchChange).toHaveBeenCalledTimes(2)
})

test('lista vazia ignora a navegação', async () => {
  server.use(
    http.get('/api/v1/accounts/1/conversations', () =>
      HttpResponse.json({ data: { meta: {}, payload: [] } }),
    ),
  )
  await renderWithApp(<ConversationList search={parseSearch({})} onSearchChange={() => {}} />)
  await screen.findByText('There are no active conversations in this group.')
  shortcut('KeyJ')
  shortcut('KeyK')
  expect(screen.getByText('There are no active conversations in this group.')).toBeInTheDocument()
})
