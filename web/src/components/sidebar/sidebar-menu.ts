// Árvore de navegação: o menuItems de components-next/sidebar/Sidebar.vue do Chatwoot, só com as telas que existem.
import type { CustomFilter, Inbox, Label, Team } from '../../api/types'

export type MenuLeaf = {
  name: string
  label: string
  icon?: string
  /** Rota da tela. Sem `to`, o item aparece só visual (a tela ainda não existe). */
  to?: string
  /** Só fica ativo na rota exata; as demais também cobrem sub-rotas. */
  exact?: boolean
  /** Inbox: mostra o ícone do canal (`telegram`, `whatsapp`...). */
  channel?: string
  /** Etiqueta: cor vem do banco (labels.color), por isso o style inline. */
  color?: string
}

export type MenuSubgroup = {
  name: string
  label: string
  icon?: string
  collapsible?: boolean
  treeLine?: boolean
  children: MenuLeaf[]
}

export type MenuChild = MenuLeaf | MenuSubgroup

export type MenuGroup = {
  name: string
  label: string
  icon: string
  children: MenuChild[]
}

export function isSubgroup(child: MenuChild): child is MenuSubgroup {
  return 'children' in child
}

// Só as visões de conversa têm tela hoje; o resto mantém o desenho do Chatwoot sem link.
export type Translate = (key: string) => string

/** Dados da conta que viram itens do menu (Sidebar.vue: teams/getMyTeams, labels/getLabelsOnSidebar). */
export type MenuData = {
  teams?: Team[]
  inboxes?: Inbox[]
  labels?: Label[]
  folders?: CustomFilter[]
}

// A ordenação por seção e os contadores de não lidas do Chatwoot ficam para depois: aqui vale a ordem do
// getter (pastas por criação, inboxes por nome).
function conversationSubgroups(
  t: Translate,
  { teams = [], inboxes = [], labels = [], folders = [] }: MenuData,
): MenuSubgroup[] {
  return [
    {
      name: 'folders',
      label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'),
      icon: 'ph-folder',
      collapsible: true,
      treeLine: true,
      children: folders.map((folder) => ({
        name: `folder-${folder.id}`,
        label: folder.name,
        to: `/app?folder_id=${folder.id}`,
      })),
    },
    {
      name: 'teams',
      label: t('SIDEBAR.TEAMS'),
      icon: 'ph-users',
      collapsible: true,
      treeLine: true,
      // o emoji do time (team.icon) não é desenhado: a sidebar só tem ícones Phosphor
      children: teams
        .filter((team) => team.is_member)
        .map((team) => ({
          name: `team-${team.id}`,
          label: team.name,
          to: `/app?team_id=${team.id}`,
        })),
    },
    {
      name: 'channels',
      label: t('SIDEBAR.CHANNELS'),
      icon: 'ph-mailbox',
      collapsible: true,
      treeLine: true,
      children: inboxes.map((inbox) => ({
        name: `inbox-${inbox.id}`,
        label: inbox.name,
        channel: inbox.channel_type,
        to: `/app?inbox_id=${inbox.id}`,
      })),
    },
    {
      name: 'labels',
      label: t('SIDEBAR.LABELS'),
      icon: 'ph-tag',
      collapsible: true,
      treeLine: true,
      children: labels
        .filter((label) => label.show_on_sidebar)
        .sort((a, b) => a.title.localeCompare(b.title))
        .map((label) => ({
          name: `label-${label.id}`,
          label: label.title,
          color: label.color,
          to: `/app?${new URLSearchParams({ label: label.title })}`,
        })),
    },
  ]
}

export function buildMenu(t: Translate, data: MenuData = {}): MenuGroup[] {
  return [
    {
      name: 'conversation',
      label: t('SIDEBAR.CONVERSATIONS'),
      icon: 'ph-chat-circle',
      children: [
        {
          name: 'all-conversations',
          label: t('SIDEBAR.ALL_CONVERSATIONS'),
          icon: 'ph-tray',
          to: '/app',
          exact: true,
        },
        {
          name: 'mentions',
          label: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
          icon: 'ph-at',
          to: '/app?conversation_type=mention',
        },
        {
          name: 'participating',
          label: t('SIDEBAR.PARTICIPATING_CONVERSATIONS'),
          icon: 'ph-user-circle',
          to: '/app?conversation_type=participating',
        },
        {
          name: 'unattended',
          label: t('SIDEBAR.UNATTENDED_CONVERSATIONS'),
          icon: 'ph-clock-countdown',
          to: '/app?conversation_type=unattended',
        },
        ...conversationSubgroups(t, data),
      ],
    },
    {
      name: 'contacts',
      label: t('SIDEBAR.CONTACTS'),
      icon: 'ph-address-book',
      children: [{ name: 'all-contacts', label: t('SIDEBAR.ALL_CONTACTS'), to: '/app/contacts' }],
    },
    {
      name: 'companies',
      label: t('SIDEBAR.COMPANIES'),
      icon: 'ph-buildings',
      children: [
        { name: 'all-companies', label: t('SIDEBAR.ALL_COMPANIES'), to: '/app/companies' },
      ],
    },
    {
      name: 'settings',
      label: t('SIDEBAR.SETTINGS'),
      icon: 'ph-lightning',
      children: [
        { name: 'settings-account', label: t('SIDEBAR.ACCOUNT_SETTINGS'), icon: 'ph-briefcase' },
        { name: 'settings-agents', label: t('SIDEBAR.AGENTS'), icon: 'ph-user-square' },
        { name: 'settings-inboxes', label: t('SIDEBAR.INBOXES'), icon: 'ph-tray' },
      ],
    },
  ]
}

/** Filhos que aparecem: subgrupos sem folhas somem (`visibleChildren` do Chatwoot). */
export function visibleChildren(group: { children: MenuChild[] }): MenuChild[] {
  return group.children.filter((c) => !isSubgroup(c) || c.children.length > 0)
}

/** Folhas navegáveis de um grupo (subgrupos achatados). */
export function leavesOf(group: { children: MenuChild[] }): MenuLeaf[] {
  return group.children.flatMap((c) => (isSubgroup(c) ? c.children : [c]))
}

function parse(to: string) {
  const url = new URL(to, 'http://x')
  return { path: url.pathname, params: url.searchParams }
}

/**
 * Folha ativa para o caminho atual (`/app?team_id=2`). Entre as que casam vence a mais específica:
 * mais parâmetros de query, depois o path mais longo (`activeChild` do SidebarGroup.vue).
 */
export function activeLeaf(menu: MenuGroup[], currentPath: string | null): string | null {
  if (!currentPath) return null
  const current = parse(currentPath)

  let best: { name: string; score: [number, number] } | null = null
  for (const leaf of menu.flatMap(leavesOf)) {
    if (!leaf.to) continue
    const target = parse(leaf.to)
    const pathMatches = leaf.exact
      ? current.path === target.path
      : current.path === target.path || current.path.startsWith(`${target.path}/`)
    const queryMatches = [...target.params].every(([k, v]) => current.params.get(k) === v)
    if (!pathMatches || !queryMatches) continue
    const score: [number, number] = [[...target.params].length, target.path.length]
    if (
      !best ||
      score[0] > best.score[0] ||
      (score[0] === best.score[0] && score[1] > best.score[1])
    ) {
      best = { name: leaf.name, score }
    }
  }
  return best?.name ?? null
}
