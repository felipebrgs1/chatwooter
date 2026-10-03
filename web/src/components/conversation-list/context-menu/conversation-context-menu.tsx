// Port de components/widgets/conversation/contextMenu/Index.vue: as ações do clique direito no card.
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { assignableAgentsQuery } from '../../../api/agents'
import { profileQuery } from '../../../api/auth'
import { labelsQuery } from '../../../api/labels'
import { teamsQuery } from '../../../api/teams'
import type {
  Agent,
  ConversationPriority,
  ConversationStatus,
  Label,
  Team,
} from '../../../api/types'
import { useAccountId } from '../../../api/use-account-id'
import { Icon } from '../../next/icon'
import { Input } from '../../next/input'
import { Spinner } from '../../next/spinner'
import { MenuItem } from './menu-item'
import { MenuItemWithSubmenu } from './menu-item-with-submenu'

type Props = {
  status: ConversationStatus
  hasUnreadMessages: boolean
  inboxId: number
  priority: ConversationPriority
  conversationLabels: string[]
  onUpdateConversation: (status: ConversationStatus) => void
  onMarkAsUnread: () => void
  onMarkAsRead: () => void
  onAssignPriority: (priority: ConversationPriority) => void
  onAssignAgent: (agent: Pick<Agent, 'id' | 'name'> | { id: null; name: string }) => void
  onAssignTeam: (team: Team) => void
  onAssignLabel: (label: Label) => void
  onRemoveLabel: (label: Label) => void
  onOpenInNewTab: () => void
  onCopyLink: () => void
  onDeleteConversation: () => void
}

const PRIORITY_OPTIONS = [
  { key: null, label: 'CONVERSATION.PRIORITY.OPTIONS.NONE' },
  { key: 'urgent', label: 'CONVERSATION.PRIORITY.OPTIONS.URGENT' },
  { key: 'high', label: 'CONVERSATION.PRIORITY.OPTIONS.HIGH' },
  { key: 'medium', label: 'CONVERSATION.PRIORITY.OPTIONS.MEDIUM' },
  { key: 'low', label: 'CONVERSATION.PRIORITY.OPTIONS.LOW' },
] as const

const AVAILABILITY_ORDER = ['online', 'busy', 'offline'] as const

const Divider = () => <hr className="m-1 rounded border-b border-n-weak dark:border-n-weak" />

export function ConversationContextMenu(props: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const { data: profile } = useQuery(profileQuery)
  const { data: labels = [] } = useQuery(labelsQuery(accountId))
  const { data: teams = [] } = useQuery(teamsQuery(accountId))
  const { data: agents = [], isFetching: agentsFetching } = useQuery(
    assignableAgentsQuery(accountId, [props.inboxId]),
  )
  const [labelSearch, setLabelSearch] = useState('')

  const membership = profile?.accounts.find((account) => account.id === accountId)
  const isAdmin = membership?.role === 'administrator'

  // getAgentsByUpdatedPresence + getSortedAgentsByAvailability: a presença do próprio usuário vem do
  // perfil; online, busy e offline, cada grupo por nome
  const presence = agents.map((agent) =>
    agent.id === profile?.id && membership
      ? { ...agent, availability_status: membership.availability_status }
      : agent,
  )
  const sortedAgents = AVAILABILITY_ORDER.flatMap((availability) =>
    presence
      .filter((agent) => agent.availability_status === availability)
      .sort((a, b) => (a.name || '').localeCompare(b.name || '')),
  )

  // picoSearch (fuzzy) vira busca por trecho; as aplicadas primeiro, mantendo a ordem de cada grupo
  const query = labelSearch.trim().toLowerCase()
  const assigned = (label: Label) => props.conversationLabels.includes(label.title)
  const filteredLabels = labels
    .filter((label) => !query || label.title.toLowerCase().includes(query))
    .sort((a, b) => Number(assigned(b)) - Number(assigned(a)))

  const statusOptions: { key: ConversationStatus; label: string; icon: string }[] = [
    { key: 'resolved', label: t('CONVERSATION.CARD_CONTEXT_MENU.RESOLVED'), icon: 'ph-check' },
    { key: 'open', label: t('CONVERSATION.CARD_CONTEXT_MENU.REOPEN'), icon: 'ph-arrow-clockwise' },
    { key: 'pending', label: t('CONVERSATION.CARD_CONTEXT_MENU.PENDING'), icon: 'ph-clock' },
  ]

  return (
    <div className="rounded-md bg-n-alpha-3/50 p-1 shadow-xl outline outline-1 outline-n-weak/50 backdrop-blur-[100px]">
      {props.hasUnreadMessages ? (
        <MenuItem
          option={{
            label: t('CONVERSATION.CARD_CONTEXT_MENU.MARK_AS_READ'),
            icon: 'ph-envelope-open',
          }}
          variant="icon"
          onClick={props.onMarkAsRead}
        />
      ) : (
        <MenuItem
          option={{
            label: t('CONVERSATION.CARD_CONTEXT_MENU.MARK_AS_UNREAD'),
            icon: 'ph-envelope',
          }}
          variant="icon"
          onClick={props.onMarkAsUnread}
        />
      )}
      <Divider />
      {statusOptions
        .filter((option) => option.key !== props.status)
        .map((option) => (
          <MenuItem
            key={option.key}
            option={option}
            variant="icon"
            onClick={() => props.onUpdateConversation(option.key)}
          />
        ))}
      {props.status === 'open' && (
        // No Chatwoot o Snooze abre o submenu da command bar (Cmd+K), que ainda não existe: só visual.
        <MenuItem
          option={{ label: t('CONVERSATION.CARD_CONTEXT_MENU.SNOOZE.TITLE'), icon: 'ph-moon' }}
          variant="icon"
          disabled
          onClick={() => {}}
        />
      )}
      <Divider />
      <MenuItemWithSubmenu option={{ label: t('CONVERSATION.PRIORITY.TITLE'), icon: 'ph-warning' }}>
        {PRIORITY_OPTIONS.filter((option) => option.key !== props.priority).map((option) => (
          <MenuItem
            key={option.key ?? 'none'}
            option={{ label: t(option.label) }}
            onClick={() => props.onAssignPriority(option.key)}
          />
        ))}
      </MenuItemWithSubmenu>
      <MenuItemWithSubmenu
        option={{ label: t('CONVERSATION.CARD_CONTEXT_MENU.ASSIGN_LABEL'), icon: 'ph-tag' }}
        subMenuAvailable={labels.length > 0}
      >
        <div className="w-[12.5rem] pb-1">
          <Input
            type="search"
            size="sm"
            className="w-full"
            inputClassName="!ps-8 !text-xs"
            value={labelSearch}
            onChange={(event) => setLabelSearch(event.target.value)}
            onClick={(event) => event.stopPropagation()}
            onKeyDown={(event) => event.stopPropagation()}
            placeholder={t('CONVERSATION.CARD_CONTEXT_MENU.SEARCH_LABELS')}
            prefix={
              <Icon
                name="ph-magnifying-glass"
                className="pointer-events-none absolute start-2 top-1/2 z-10 size-3.5 -translate-y-1/2 text-n-slate-10"
              />
            }
          />
        </div>
        <div className="max-h-[12.5rem] overflow-y-auto overflow-x-hidden">
          {filteredLabels.map((label) => (
            <MenuItem
              key={label.id}
              option={{ label: label.title, color: label.color }}
              variant={assigned(label) ? 'label-assigned' : 'label'}
              onClick={() =>
                assigned(label) ? props.onRemoveLabel(label) : props.onAssignLabel(label)
              }
            />
          ))}
          {filteredLabels.length === 0 && (
            <p className="m-0 px-2 py-2 text-center text-xs text-n-slate-11">
              {t('CONVERSATION.CARD_CONTEXT_MENU.NO_LABELS_FOUND')}
            </p>
          )}
        </div>
      </MenuItemWithSubmenu>
      <MenuItemWithSubmenu
        option={{ label: t('CONVERSATION.CARD_CONTEXT_MENU.ASSIGN_AGENT'), icon: 'ph-user-plus' }}
      >
        {agentsFetching ? (
          <div className="flex min-w-[12.5rem] flex-col items-center justify-center py-4">
            <Spinner />
            <p className="mt-2 mb-0">{t('CONVERSATION.CARD_CONTEXT_MENU.AGENTS_LOADING')}</p>
          </div>
        ) : (
          <>
            {/* o Chatwoot escreve "None" fixo; aqui vem do i18n */}
            <MenuItem
              option={{ label: t('AGENT_MGMT.MULTI_SELECTOR.LIST.NONE') }}
              variant="agent"
              onClick={() =>
                props.onAssignAgent({ id: null, name: t('AGENT_MGMT.MULTI_SELECTOR.LIST.NONE') })
              }
            />
            {sortedAgents.map((agent) => (
              <MenuItem
                key={agent.id}
                option={{
                  label: agent.name,
                  thumbnail: agent.thumbnail,
                  status: agent.availability_status,
                }}
                variant="agent"
                onClick={() => props.onAssignAgent(agent)}
              />
            ))}
          </>
        )}
      </MenuItemWithSubmenu>
      <MenuItemWithSubmenu
        option={{ label: t('CONVERSATION.CARD_CONTEXT_MENU.ASSIGN_TEAM'), icon: 'ph-users-three' }}
        subMenuAvailable={teams.length > 0}
      >
        {teams.map((team) => (
          <MenuItem
            key={team.id}
            option={{ label: team.name }}
            onClick={() => props.onAssignTeam(team)}
          />
        ))}
      </MenuItemWithSubmenu>
      <Divider />
      <MenuItem
        option={{
          label: t('CONVERSATION.CARD_CONTEXT_MENU.OPEN_IN_NEW_TAB'),
          icon: 'ph-arrow-square-out',
        }}
        variant="icon"
        onClick={props.onOpenInNewTab}
      />
      <MenuItem
        option={{ label: t('CONVERSATION.CARD_CONTEXT_MENU.COPY_LINK'), icon: 'ph-copy' }}
        variant="icon"
        onClick={props.onCopyLink}
      />
      {isAdmin && (
        <>
          <Divider />
          <MenuItem
            option={{ label: t('CONVERSATION.CARD_CONTEXT_MENU.DELETE'), icon: 'ph-trash' }}
            variant="icon"
            onClick={props.onDeleteConversation}
          />
        </>
      )}
    </div>
  )
}
