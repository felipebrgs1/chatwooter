// Port de routes/dashboard/conversation/ConversationAction.vue: responsável, time, prioridade e etiquetas.
// Sugestões do Captain (enterprise) e bots como responsáveis (agent bots) ainda não entram.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { agentsQuery } from '../../../api/agents'
import {
  assignConversation,
  conversationKeys,
  conversationLabelsQuery,
  togglePriority,
  updateConversationLabels,
} from '../../../api/conversations'
import { labelsQuery } from '../../../api/labels'
import { profileQuery } from '../../../api/auth'
import { teamsQuery } from '../../../api/teams'
import type { Conversation, ConversationPriority } from '../../../api/types'
import { useAccountId } from '../../../api/use-account-id'
import { PRIORITIES } from '../../conversation-list/card-helpers'
import { Icon } from '../../next/icon'
import { showAlert } from '../../toast/alert'
import { ContactDetailsItem } from './contact-details-item'
import { LabelBox } from './label-box'
import { MultiselectDropdown, type MultiselectOption } from './multiselect-dropdown'

type Props = { conversation: Conversation }

// ordem do priorityOptions: none, urgent, high, medium, low
const PRIORITY_ORDER = ['urgent', 'high', 'medium', 'low'] as const

export function ConversationAction({ conversation }: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const queryClient = useQueryClient()
  const { data: profile } = useQuery(profileQuery)
  const { data: agents = [] } = useQuery(agentsQuery(accountId))
  const { data: teams = [] } = useQuery(teamsQuery(accountId))
  const { data: accountLabels = [] } = useQuery(labelsQuery(accountId))
  const labelsKey = conversationLabelsQuery(accountId, conversation.id).queryKey
  const { data: savedLabels = conversation.labels } = useQuery(
    conversationLabelsQuery(accountId, conversation.id),
  )
  const detailKey = conversationKeys.detail(accountId, conversation.id)

  // a lista também mostra responsável, prioridade e etiquetas: recarrega depois de cada mudança
  const refreshLists = () =>
    queryClient.invalidateQueries({ queryKey: [...conversationKeys.all(accountId), 'list'] })
  const patch = (change: Partial<Conversation> | ((c: Conversation) => Conversation)) =>
    queryClient.setQueryData<Conversation>(
      detailKey,
      (c) => c && (typeof change === 'function' ? change(c) : { ...c, ...change }),
    )

  const assign = useMutation({
    mutationFn: (body: { assignee_id?: number | null; team_id?: number | null }) =>
      assignConversation(accountId, conversation.id, body),
    onSuccess: (_, body) => {
      showAlert(t('assignee_id' in body ? 'CONVERSATION.CHANGE_AGENT' : 'CONVERSATION.CHANGE_TEAM'))
      void refreshLists()
    },
  })

  const priority = useMutation({
    mutationFn: (value: ConversationPriority) => togglePriority(accountId, conversation.id, value),
    onSuccess: (_, value) => {
      const name = t(value ? PRIORITIES[value].key : 'CONVERSATION.PRIORITY.OPTIONS.NONE')
      showAlert(
        t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
          priority: name,
          conversationId: conversation.id,
        }),
      )
      void refreshLists()
    },
  })

  const labels = useMutation({
    mutationFn: (next: string[]) => updateConversationLabels(accountId, conversation.id, next),
    onMutate: (next) => {
      const previous = queryClient.getQueryData<string[]>(labelsKey)
      queryClient.setQueryData(labelsKey, next)
      return { previous }
    },
    onError: (_, __, context) => queryClient.setQueryData(labelsKey, context?.previous),
    onSuccess: (saved) => {
      queryClient.setQueryData(labelsKey, saved)
      patch({ labels: saved })
      void refreshLists()
    },
  })

  const assignee = conversation.meta.assignee
  const assignedAgent: MultiselectOption | null = assignee
    ? {
        id: assignee.id,
        name: assignee.name,
        thumbnail: assignee.thumbnail,
        availability_status: assignee.availability_status,
      }
    : null
  const agentOptions: MultiselectOption[] = agents.map((agent) => ({
    id: agent.id,
    name: agent.name,
    thumbnail: agent.thumbnail,
    availability_status: agent.availability_status,
  }))
  const setAgent = (agentId: number | null) => {
    const agent = agents.find((a) => a.id === agentId)
    patch((c) => ({ ...c, meta: { ...c.meta, assignee: agent } }))
    assign.mutate({ assignee_id: agentId })
  }

  const team = conversation.meta.team
  // com time escolhido, a lista ganha "None" para tirar o time
  const teamOptions: MultiselectOption[] = [
    ...(team ? [{ id: 0, name: t('TEAMS_SETTINGS.LIST.NONE') }] : []),
    ...teams.map((tm) => ({ id: tm.id, name: tm.name })),
  ]
  const setTeam = (teamId: number | null) => {
    const next = teams.find((tm) => tm.id === teamId)
    patch((c) => ({ ...c, meta: { ...c.meta, team: next } }))
    // teamId 0 ("None") desatribui, como o assignTeam do Chatwoot
    assign.mutate({ team_id: teamId ?? 0 })
  }

  const priorityOptions: MultiselectOption[] = [
    { id: null, name: t('CONVERSATION.PRIORITY.OPTIONS.NONE') },
    ...PRIORITY_ORDER.map((id) => ({ id, name: t(PRIORITIES[id].key), icon: PRIORITIES[id].icon })),
  ]
  const assignedPriority =
    priorityOptions.find((o) => o.id === conversation.priority) ?? priorityOptions[0]
  const setPriority = (value: ConversationPriority) => {
    patch({ priority: value })
    priority.mutate(value)
  }

  const showSelfAssign = !assignee || assignee.id !== profile?.id

  return (
    <div>
      <div>
        <ContactDetailsItem
          compact
          title={t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL')}
          button={
            showSelfAssign && (
              <button
                type="button"
                className="inline-flex items-center !gap-1 text-xs font-medium text-n-blue-11 hover:underline"
                onClick={() => profile && setAgent(profile.id)}
              >
                <Icon name="ph-arrow-right" />
                {t('CONVERSATION_SIDEBAR.SELF_ASSIGN')}
              </button>
            )
          }
        />
        <MultiselectDropdown
          options={agentOptions}
          selectedItem={assignedAgent}
          multiselectorTitle={t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')}
          multiselectorPlaceholder={t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')}
          noSearchResult={t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')}
          inputPlaceholder={t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')}
          onSelect={(option) => setAgent(assignee?.id === option.id ? null : (option.id as number))}
        />
      </div>
      <div>
        <ContactDetailsItem compact title={t('CONVERSATION_SIDEBAR.TEAM_LABEL')} />
        <MultiselectDropdown
          options={teamOptions}
          selectedItem={team ? { id: team.id, name: team.name } : null}
          hasThumbnail={false}
          multiselectorTitle={t('AGENT_MGMT.MULTI_SELECTOR.TITLE.TEAM')}
          multiselectorPlaceholder={t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')}
          noSearchResult={t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')}
          inputPlaceholder={t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.TEAM')}
          onSelect={(option) =>
            setTeam(team?.id === option.id || option.id === 0 ? null : (option.id as number))
          }
        />
      </div>
      <div>
        <ContactDetailsItem compact title={t('CONVERSATION.PRIORITY.TITLE')} />
        <MultiselectDropdown
          options={priorityOptions}
          selectedItem={assignedPriority}
          hasThumbnail={false}
          multiselectorTitle={t('CONVERSATION.PRIORITY.TITLE')}
          multiselectorPlaceholder={t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SELECT_PLACEHOLDER')}
          noSearchResult={t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.NO_RESULTS')}
          inputPlaceholder={t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.INPUT_PLACEHOLDER')}
          onSelect={(option) =>
            setPriority(
              assignedPriority.id === option.id ? null : (option.id as ConversationPriority),
            )
          }
        />
      </div>
      <ContactDetailsItem compact title={t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')} />
      <LabelBox
        savedLabels={savedLabels}
        accountLabels={accountLabels}
        onAdd={(title) => labels.mutate([...savedLabels, title])}
        onRemove={(title) => labels.mutate(savedLabels.filter((l) => l !== title))}
      />
    </div>
  )
}
