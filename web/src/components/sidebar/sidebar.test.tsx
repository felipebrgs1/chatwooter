import { act, fireEvent, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, test, vi } from 'vitest'

import { accountFixture, profileFixture } from '../../test/fixtures'
import { renderWithI18n } from '../../test/i18n'
import { Sidebar } from './sidebar'

function props(overrides: Partial<Parameters<typeof Sidebar>[0]> = {}) {
  return {
    profile: profileFixture(),
    currentAccountId: 1,
    activePath: '/app',
    width: 200,
    onWidthChange: vi.fn(),
    onToggleCollapse: vi.fn(),
    mobileOpen: false,
    onMobileOpenChange: vi.fn(),
    onSignOut: vi.fn(),
    onAvailabilityChange: vi.fn(),
    onAutoOfflineChange: vi.fn(),
    onSwitchAccount: vi.fn(),
    ...overrides,
  }
}

describe('Sidebar expandida', () => {
  test('mostra a conta atual, a busca e os grupos de navegação', async () => {
    await renderWithI18n(<Sidebar {...props()} />)
    const nav = screen.getByRole('navigation')
    expect(screen.getByText('Acme')).toBeInTheDocument()
    expect(screen.getByText('Search...')).toBeInTheDocument()
    for (const label of ['Conversations', 'Contacts', 'Companies', 'Settings']) {
      expect(within(nav).getByTitle(label)).toBeInTheDocument()
    }
  })

  test('a rota atual fica marcada como página e leva para /app', async () => {
    await renderWithI18n(<Sidebar {...props()} />)
    const link = screen.getByRole('link', { name: 'All Conversations' })
    expect(link).toHaveAttribute('href', '/app')
    expect(link).toHaveAttribute('aria-current', 'page')
  })

  test('itens sem tela ainda não viram link', async () => {
    await renderWithI18n(<Sidebar {...props()} />)
    expect(screen.queryByRole('link', { name: 'All Contacts' })).not.toBeInTheDocument()
    expect(screen.getByText('All Contacts')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Mentions' })).toHaveAttribute(
      'href',
      '/app?conversation_type=mention',
    )
  })

  test('usa o renderizador de link do pai (roteador)', async () => {
    await renderWithI18n(
      <Sidebar
        {...props({
          renderLink: ({ to, children, ...rest }) => (
            <a data-router-link="true" href={to} {...rest}>
              {children}
            </a>
          ),
        })}
      />,
    )
    expect(screen.getByRole('link', { name: 'All Conversations' })).toHaveAttribute(
      'data-router-link',
      'true',
    )
  })

  test('o grupo ativo abre e fecha pelo cabeçalho', async () => {
    const user = userEvent.setup()
    await renderWithI18n(<Sidebar {...props()} />)
    const group = document.getElementById('sidebar-group-conversation')!
    expect(group).toHaveAttribute('data-expanded', 'true')
    await user.click(within(group).getByRole('button', { name: 'Conversations' }))
    expect(group).toHaveAttribute('data-expanded', 'false')
    await user.click(within(group).getByRole('button', { name: 'Conversations' }))
    expect(group).toHaveAttribute('data-expanded', 'true')
  })

  test('grupo sem tela abre pelo cabeçalho para mostrar os filhos', async () => {
    const user = userEvent.setup()
    await renderWithI18n(<Sidebar {...props()} />)
    const group = document.getElementById('sidebar-group-contacts')!
    expect(group).toHaveAttribute('data-expanded', 'false')
    await user.click(within(group).getByRole('button', { name: 'Contacts' }))
    expect(group).toHaveAttribute('data-expanded', 'true')
  })
})

describe('Sidebar recolhida', () => {
  test('só ícones, sem nome da conta nem texto de busca', async () => {
    await renderWithI18n(<Sidebar {...props({ width: 56 })} />)
    expect(screen.queryByText('Search...')).not.toBeInTheDocument()
    expect(screen.queryByText('Acme')).not.toBeInTheDocument()
    expect(screen.getByRole('complementary')).toHaveAttribute('data-collapsed', 'true')
    expect(screen.getByTitle('Conversations')).toBeInTheDocument()
  })

  test('no mobile a sidebar é sempre expandida', async () => {
    await renderWithI18n(<Sidebar {...props({ width: 56, isMobile: true })} />)
    expect(screen.getByRole('complementary')).toHaveAttribute('data-collapsed', 'false')
    expect(screen.getByText('Acme')).toBeInTheDocument()
  })

  test('passar o mouse no ícone abre o popover do grupo e sair o fecha', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    try {
      const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
      await renderWithI18n(<Sidebar {...props({ width: 56 })} />)
      const popover = document.getElementById('sidebar-popover-conversation')!
      expect(popover).toHaveAttribute('hidden')

      await user.hover(screen.getByTitle('Conversations'))
      expect(popover).not.toHaveAttribute('hidden')
      expect(within(popover).getByText('All Conversations')).toBeInTheDocument()

      await user.unhover(screen.getByTitle('Conversations'))
      await act(() => vi.advanceTimersByTimeAsync(300))
      expect(popover).toHaveAttribute('hidden')
    } finally {
      vi.useRealTimers()
    }
  })
})

describe('menu do perfil', () => {
  test('mostra nome e e-mail e abre com o clique', async () => {
    const user = userEvent.setup()
    await renderWithI18n(<Sidebar {...props()} />)
    expect(screen.getByText('ana@example.com')).toBeInTheDocument()
    expect(screen.queryByText('Set your availability')).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: /Ana Souza/ }))
    expect(screen.getByText('Set your availability')).toBeInTheDocument()
  })

  test('trocar a disponibilidade avisa o pai', async () => {
    const user = userEvent.setup()
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    await user.click(screen.getByRole('button', { name: /Ana Souza/ }))
    await user.click(screen.getByRole('button', { name: 'Online' }))
    await user.click(screen.getByRole('button', { name: 'Busy' }))
    expect(p.onAvailabilityChange).toHaveBeenCalledWith('busy')
  })

  test('o interruptor "marcar offline automaticamente" avisa o pai', async () => {
    const user = userEvent.setup()
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    await user.click(screen.getByRole('button', { name: /Ana Souza/ }))
    await user.click(screen.getByRole('switch'))
    expect(p.onAutoOfflineChange).toHaveBeenCalledWith(true)
  })

  test('sair chama onSignOut', async () => {
    const user = userEvent.setup()
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    await user.click(screen.getByRole('button', { name: /Ana Souza/ }))
    await user.click(screen.getByRole('button', { name: 'Log out' }))
    expect(p.onSignOut).toHaveBeenCalledOnce()
  })

  test('o estado do interruptor e a disponibilidade vêm da conta atual', async () => {
    const user = userEvent.setup()
    const profile = profileFixture({
      accounts: [
        accountFixture({ availability: 'busy', availability_status: 'busy', auto_offline: true }),
      ],
    })
    await renderWithI18n(<Sidebar {...props({ profile })} />)
    await user.click(screen.getByRole('button', { name: /Ana Souza/ }))
    expect(screen.getByRole('switch')).toBeChecked()
    expect(screen.getByRole('button', { name: 'Busy' })).toBeInTheDocument()
  })
})

describe('troca de conta', () => {
  test('lista só as contas do perfil e troca pela escolhida', async () => {
    const user = userEvent.setup()
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    await user.click(screen.getByRole('button', { name: /Acme/ }))
    expect(screen.getByText('Switch account')).toBeInTheDocument()
    const list = screen.getByRole('list', { name: 'Switch account' })
    expect(within(list).getAllByRole('listitem')).toHaveLength(2)
    await user.click(within(list).getByRole('button', { name: /Globex/ }))
    expect(p.onSwitchAccount).toHaveBeenCalledWith(2)
  })

  test('a conta atual fica marcada e não dispara troca', async () => {
    const user = userEvent.setup()
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    await user.click(screen.getByRole('button', { name: /Acme/ }))
    const list = screen.getByRole('list', { name: 'Switch account' })
    const current = within(list).getByRole('button', { name: /Acme/ })
    expect(current).toHaveAttribute('aria-current', 'true')
    await user.click(current)
    expect(p.onSwitchAccount).not.toHaveBeenCalled()
  })

  test('recolhida, o logo abre a mesma lista', async () => {
    const user = userEvent.setup()
    await renderWithI18n(<Sidebar {...props({ width: 56 })} />)
    await user.click(screen.getByTitle('Acme'))
    expect(screen.getByText('Globex')).toBeInTheDocument()
  })
})

describe('mobile', () => {
  test('o launcher abre o flyout e clicar fora o fecha', async () => {
    const user = userEvent.setup()
    const p = props()
    const { rerender } = await renderWithI18n(<Sidebar {...p} />)
    expect(screen.getByRole('complementary')).toHaveAttribute('data-mobile-open', 'false')
    await user.click(screen.getByRole('button', { name: 'Toggle Sidebar' }))
    expect(p.onMobileOpenChange).toHaveBeenCalledWith(true)

    const open = props({ ...p, mobileOpen: true })
    rerender(<Sidebar {...open} />)
    expect(screen.getByRole('complementary')).toHaveAttribute('data-mobile-open', 'true')
    await user.click(document.body)
    expect(open.onMobileOpenChange).toHaveBeenCalledWith(false)
  })

  test('esconde o launcher quando há conversa aberta', async () => {
    await renderWithI18n(<Sidebar {...props({ hideMobileLauncher: true })} />)
    expect(screen.queryByRole('button', { name: 'Toggle Sidebar' })).not.toBeInTheDocument()
  })
})

describe('redimensionar', () => {
  function handle() {
    return document.getElementById('sidebar-resize-handle')!
  }

  test('arrastar avisa a largura e, ao soltar, confirma', async () => {
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    fireEvent.mouseDown(handle(), { clientX: 200 })
    fireEvent.mouseMove(document, { clientX: 260 })
    expect(p.onWidthChange).toHaveBeenLastCalledWith(260, false)
    fireEvent.mouseUp(document)
    expect(p.onWidthChange).toHaveBeenLastCalledWith(260, true)
  })

  test('respeita os limites de 56 a 320', async () => {
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    fireEvent.mouseDown(handle(), { clientX: 200 })
    fireEvent.mouseMove(document, { clientX: 900 })
    expect(p.onWidthChange).toHaveBeenLastCalledWith(320, false)
    fireEvent.mouseUp(document)
  })

  test('soltar abaixo do limiar de recolher encaixa no mínimo', async () => {
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    fireEvent.mouseDown(handle(), { clientX: 200 })
    fireEvent.mouseMove(document, { clientX: 100 })
    fireEvent.mouseUp(document)
    expect(p.onWidthChange).toHaveBeenLastCalledWith(56, true)
  })

  test('duplo clique alterna recolhida/expandida', async () => {
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    fireEvent.doubleClick(handle())
    expect(p.onToggleCollapse).toHaveBeenCalledOnce()
  })

  test('movimento sem arrastar não faz nada', async () => {
    const p = props()
    await renderWithI18n(<Sidebar {...p} />)
    fireEvent.mouseMove(document, { clientX: 300 })
    expect(p.onWidthChange).not.toHaveBeenCalled()
  })
})
