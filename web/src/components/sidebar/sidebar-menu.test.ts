import { describe, expect, test } from 'vitest'

import { inboxFixture } from '../../test/conversation-fixtures'
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

  test('conversas, contatos e empresas têm rota; settings ainda não tem tela', () => {
    const withRoute = menu.flatMap(leavesOf).filter((leaf) => leaf.to)
    expect(withRoute.map((l) => [l.name, l.to])).toEqual([
      ['all-conversations', '/app'],
      ['mentions', '/app?conversation_type=mention'],
      ['participating', '/app?conversation_type=participating'],
      ['unattended', '/app?conversation_type=unattended'],
      ['all-contacts', '/app/contacts'],
      ['all-companies', '/app/companies'],
    ])
  })

  test('sem times nem etiquetas os subgrupos somem', () => {
    const conversations = menu[0]!
    expect(visibleChildren(conversations).map((c) => c.name)).not.toContain('teams')
    expect(visibleChildren(conversations).map((c) => c.name)).not.toContain('labels')
  })
})

describe('buildMenu com times e etiquetas', () => {
  const team = (id: number, name: string, is_member: boolean) => ({
    id,
    name,
    is_member,
    description: null,
    allow_auto_assign: true,
    icon: '',
    icon_color: '',
    account_id: 1,
  })
  const label = (id: number, title: string, show_on_sidebar: boolean) => ({
    id,
    title,
    show_on_sidebar,
    description: null,
    color: `#00000${id}`,
  })
  const menu = buildMenu(t, {
    teams: [team(1, 'Suporte', true), team(2, 'Vendas', false)],
    labels: [label(1, 'vip', true), label(2, 'oculta', false), label(3, 'cobrança', true)],
  })
  const child = (name: string) => menu[0]!.children.find((c) => c.name === name)

  test('Teams mostra só os times de que o usuário faz parte (getMyTeams)', () => {
    const teams = child('teams')
    expect(teams && leavesOf({ children: [teams] }).map((l) => [l.label, l.to])).toEqual([
      ['Suporte', '/app?team_id=1'],
    ])
  })

  test('Channels lista as inboxes com o ícone do canal, entre Teams e Labels', () => {
    const withInboxes = buildMenu(t, {
      inboxes: [
        inboxFixture({ id: 3, name: 'Zap', channel_type: 'Channel::Whatsapp' }),
        inboxFixture({ id: 4, name: 'Bot' }),
      ],
    })
    const children = withInboxes[0]!.children
    expect(children.map((c) => c.name).slice(-3)).toEqual(['teams', 'channels', 'labels'])
    const channels = children.find((c) => c.name === 'channels')!
    expect(leavesOf({ children: [channels] }).map((l) => [l.label, l.to, l.channel])).toEqual([
      ['Zap', '/app?inbox_id=3', 'Channel::Whatsapp'],
      ['Bot', '/app?inbox_id=4', 'Channel::Telegram'],
    ])
  })

  test('Labels mostra as da sidebar, por título, com a cor', () => {
    const labels = child('labels')
    expect(labels && leavesOf({ children: [labels] }).map((l) => [l.label, l.to, l.color])).toEqual(
      [
        ['cobrança', '/app?label=cobran%C3%A7a', '#000003'],
        ['vip', '/app?label=vip', '#000001'],
      ],
    )
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
