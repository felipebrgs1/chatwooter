import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, test, vi } from 'vitest'

import { renderWithI18n } from '../../test/i18n'
import { Sidebar } from './sidebar'
import type { MenuGroup } from './sidebar-menu'
import { profileFixture } from '../../test/fixtures'

const menu: MenuGroup[] = [
  {
    name: 'conversation',
    label: 'Conversations',
    icon: 'ph-chat-circle',
    children: [
      { name: 'all', label: 'All', icon: 'ph-tray', to: '/app', exact: true },
      {
        name: 'teams',
        label: 'Teams',
        icon: 'ph-users',
        collapsible: true,
        treeLine: true,
        children: [
          { name: 'team-1', label: 'Suporte', to: '/app?team_id=1' },
          { name: 'team-2', label: 'Vendas', to: '/app?team_id=2' },
        ],
      },
      { name: 'labels', label: 'Labels', icon: 'ph-tag', collapsible: true, children: [] },
      {
        name: 'channels',
        label: 'Channels',
        icon: 'ph-broadcast',
        collapsible: true,
        children: [
          { name: 'inbox-1', label: 'Telegram', channel: 'telegram', to: '/app?inbox_id=1' },
        ],
      },
    ],
  },
]

function setup(overrides: Partial<Parameters<typeof Sidebar>[0]> = {}) {
  const p = {
    profile: profileFixture(),
    currentAccountId: 1,
    activePath: '/app?team_id=2',
    width: 200,
    menu,
    onWidthChange: vi.fn(),
    onToggleCollapse: vi.fn(),
    mobileOpen: false,
    onMobileOpenChange: vi.fn(),
    onSignOut: vi.fn(),
    onAvailabilityChange: vi.fn(),
    onAutoOfflineChange: vi.fn(),
    onSwitchAccount: vi.fn(),
    onToggleSection: vi.fn(),
    ...overrides,
  }
  return p
}

describe('subgrupos', () => {
  test('mostra as folhas e marca a ativa; subgrupo vazio some', async () => {
    await renderWithI18n(<Sidebar {...setup()} />)
    expect(screen.getByRole('link', { name: 'Vendas' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: 'Suporte' })).not.toHaveAttribute('aria-current')
    expect(screen.queryByText('Labels')).not.toBeInTheDocument()
  })

  test('recolher uma seção avisa o pai com a chave conta:grupo:seção', async () => {
    const user = userEvent.setup()
    const p = setup()
    await renderWithI18n(<Sidebar {...p} />)
    const section = document.getElementById('sidebar-section-channels')!
    await user.click(within(section).getByRole('button', { name: 'Channels' }))
    expect(p.onToggleSection).toHaveBeenCalledWith('1:conversation:channels')
  })

  test('seção minimizada fica marcada, exceto se tem o item ativo', async () => {
    const p = setup({
      minimizedSections: { '1:conversation:channels': true, '1:conversation:teams': true },
    })
    await renderWithI18n(<Sidebar {...p} />)
    expect(document.getElementById('sidebar-section-channels')).toHaveAttribute(
      'data-minimized',
      'true',
    )
    expect(document.getElementById('sidebar-section-teams')).toHaveAttribute(
      'data-minimized',
      'false',
    )
  })

  test('seção não colapsável não tem botão de recolher', async () => {
    const plain: MenuGroup[] = [
      {
        ...menu[0],
        children: [
          { name: 'fixed', label: 'Fixed', children: [{ name: 'x', label: 'X', to: '/app' }] },
        ],
      },
    ]
    await renderWithI18n(<Sidebar {...setup({ menu: plain, activePath: '/app' })} />)
    const section = document.getElementById('sidebar-section-fixed')!
    expect(within(section).queryByRole('button')).not.toBeInTheDocument()
  })

  test('lista longa vira rolável', async () => {
    const many: MenuGroup[] = [
      {
        ...menu[0],
        children: [
          {
            name: 'teams',
            label: 'Teams',
            collapsible: true,
            children: Array.from({ length: 8 }, (_, i) => ({
              name: `t${i}`,
              label: `Time ${i}`,
              to: `/app?team_id=${i}`,
            })),
          },
        ],
      },
    ]
    await renderWithI18n(<Sidebar {...setup({ menu: many, activePath: '/app?team_id=1' })} />)
    expect(document.querySelector('[data-section-scroll]')?.className).toMatch(/overflow-y-scroll/)
  })
})
