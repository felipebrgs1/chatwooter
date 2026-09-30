import { describe, expect, test } from 'vitest'

import { activeLeaf, buildMenu, leavesOf, visibleChildren, type MenuGroup } from './sidebar-menu'

const t = (key: string) => key

describe('buildMenu', () => {
  const menu = buildMenu(t)

  test('tem os grupos do Chatwoot com os textos vindos do i18n', () => {
    expect(menu.map((g) => g.label)).toEqual([
      'SIDEBAR.CONVERSATIONS',
      'SIDEBAR.CONTACTS',
      'SIDEBAR.COMPANIES',
      'SIDEBAR.SETTINGS',
    ])
  })

  test('só "All Conversations" tem rota; o resto ainda não tem tela', () => {
    const withRoute = menu.flatMap(leavesOf).filter((leaf) => leaf.to)
    expect(withRoute.map((l) => [l.name, l.to])).toEqual([['all-conversations', '/app']])
  })
})

describe('activeLeaf', () => {
  const menu: MenuGroup[] = [
    {
      name: 'conversation',
      label: 'Conversations',
      icon: 'ph-chat-circle',
      children: [
        { name: 'all', label: 'All', to: '/app', exact: true },
        { name: 'mentions', label: 'Mentions', to: '/app?conversation_type=mention' },
        { name: 'inbox-1', label: 'Inbox 1', to: '/app?inbox_id=1' },
      ],
    },
    {
      name: 'contacts',
      label: 'Contacts',
      icon: 'ph-address-book',
      children: [{ name: 'all-contacts', label: 'All', to: '/app/contacts' }],
    },
  ]

  test('rota exata', () => expect(activeLeaf(menu, '/app')).toBe('all'))
  test('vence a folha com mais parâmetros de query', () =>
    expect(activeLeaf(menu, '/app?conversation_type=mention')).toBe('mentions'))
  test('folha não exata cobre sub-rotas', () =>
    expect(activeLeaf(menu, '/app/contacts/12')).toBe('all-contacts'))
  test('folha exata não cobre sub-rotas', () => expect(activeLeaf(menu, '/app/x')).toBeNull())
  test('sem caminho não há folha ativa', () => expect(activeLeaf(menu, null)).toBeNull())
  test('ignora folhas sem rota', () => {
    const visual: MenuGroup[] = [
      { name: 'g', label: 'G', icon: 'ph-tray', children: [{ name: 'x', label: 'X' }] },
    ]
    expect(activeLeaf(visual, '/app')).toBeNull()
  })
})

describe('leavesOf / visibleChildren', () => {
  const group: MenuGroup = {
    name: 'g',
    label: 'G',
    icon: 'ph-tray',
    children: [
      { name: 'a', label: 'A' },
      { name: 'empty', label: 'Empty', children: [] },
      { name: 'sub', label: 'Sub', children: [{ name: 'b', label: 'B' }] },
    ],
  }

  test('achata os subgrupos', () => expect(leavesOf(group).map((l) => l.name)).toEqual(['a', 'b']))
  test('subgrupos vazios somem', () =>
    expect(visibleChildren(group).map((c) => c.name)).toEqual(['a', 'sub']))
})
