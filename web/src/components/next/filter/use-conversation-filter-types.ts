// Port de components-next/filter/provider.js + operators.js + helper/filterAttributeIcons.js: os atributos do
// filtro de conversas, seus operadores e opções. Ícones lucide do Chatwoot viram os equivalentes Phosphor.
import { useQuery } from '@tanstack/react-query'
import { useCallback, useMemo } from 'react'
import { useTranslation } from 'react-i18next'

import { agentsQuery } from '../../../api/agents'
import { api } from '../../../api/client'
import { inboxesQuery } from '../../../api/inboxes'
import { labelsQuery } from '../../../api/labels'
import { teamsQuery } from '../../../api/teams'
import type { ContactsPage } from '../../../api/types'
import { useAccountId } from '../../../api/use-account-id'
import { LANGUAGES } from '../../../shared/languages'
import { channelIconName } from '../channel-icon-name'
import { STANDARD_INPUT_TYPES, type FilterLists, type InputType } from './filter-query'

export type ValueOption = {
  id: string | number | boolean
  name: string
  icon?: string
  color?: string
}

export type Operator = { value: string; label: string; icon: string; hasInput: boolean }

/** Item do FilterSelect: atributo, operador ou cabeçalho de grupo (disabled). */
export type SelectOption = { value: string; label: string; icon?: string; disabled?: boolean }

export type FilterType = {
  attributeKey: string
  label: string
  icon: string
  inputType: InputType
  options?: ValueOption[]
  filterOperators: Operator[]
  attributeModel: 'standard' | 'additional' | 'customAttributes'
  searchOptions?: (query: string) => Promise<ValueOption[]>
  searchPlaceholder?: string
}

const OPERATOR_ICONS: Record<string, string> = {
  equal_to: 'ph-equals-bold',
  not_equal_to: 'ph-not-equals-bold',
  is_present: 'ph-member-of-bold',
  is_not_present: 'ph-not-member-of-bold',
  contains: 'ph-superset-of-bold',
  does_not_contain: 'ph-not-superset-of-bold',
  is_greater_than: 'ph-greater-than-bold',
  is_less_than: 'ph-less-than-bold',
  days_before: 'ph-calendar-minus-bold',
}

const ATTRIBUTE_ICONS: Record<string, string> = {
  status: 'ph-record',
  priority: 'ph-cell-signal-high',
  assignee_id: 'ph-user',
  inbox_id: 'ph-tray',
  team_id: 'ph-users',
  contact_id: 'ph-address-book',
  display_id: 'ph-hash',
  campaign_id: 'ph-megaphone',
  browser_language: 'ph-globe',
  referer: 'ph-link',
  labels: 'ph-tag',
  created_at: 'ph-calendar',
  last_activity_at: 'ph-pulse',
}

const GROUPS = [
  { model: 'standard', labelKey: 'STANDARD_FILTERS' },
  { model: 'additional', labelKey: 'ADDITIONAL_FILTERS' },
  { model: 'customAttributes', labelKey: 'CUSTOM_ATTRIBUTES' },
] as const

const EQUALITY = ['equal_to', 'not_equal_to']
const PRESENCE = ['equal_to', 'not_equal_to', 'is_present', 'is_not_present']
const CONTAINMENT = ['equal_to', 'not_equal_to', 'contains', 'does_not_contain']
const DATES = ['is_greater_than', 'is_less_than', 'days_before']

export const PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const
const STATUSES = ['open', 'resolved', 'pending', 'snoozed', 'all'] as const

export function useConversationFilterTypes() {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const { data: labels = [] } = useQuery(labelsQuery(accountId))
  const { data: agents = [] } = useQuery(agentsQuery(accountId))
  const { data: inboxes = [] } = useQuery(inboxesQuery(accountId))
  const { data: teams = [] } = useQuery(teamsQuery(accountId))

  // createContactSearcher: busca de contatos para o filtro por contato
  const searchContacts = useCallback(
    async (query: string): Promise<ValueOption[]> => {
      const page = await api.get<ContactsPage>(
        `/api/v1/accounts/${accountId}/contacts/search?q=${encodeURIComponent(query)}&page=1`,
      )
      return page.payload.map((contact) => ({
        id: contact.id,
        name:
          contact.name ||
          contact.email ||
          contact.phone_number ||
          contact.identifier ||
          t('FILTER.CONTACT_FALLBACK', { id: contact.id }),
      }))
    },
    [accountId, t],
  )

  return useMemo(() => {
    const operators = (values: string[]): Operator[] =>
      values.map((value) => ({
        value,
        label: t(`FILTER.OPERATOR_LABELS.${value}`),
        icon: OPERATOR_ICONS[value],
        hasInput: value !== 'is_present' && value !== 'is_not_present',
      }))
    const type = (
      attributeKey: string,
      i18nKey: string,
      filterOperators: string[],
      extra: Partial<FilterType> = {},
    ): FilterType => ({
      attributeKey,
      label: t(`FILTER.ATTRIBUTES.${i18nKey}`),
      icon: ATTRIBUTE_ICONS[attributeKey],
      inputType: STANDARD_INPUT_TYPES[attributeKey],
      filterOperators: operators(filterOperators),
      attributeModel: 'standard',
      ...extra,
    })
    const priorities = PRIORITIES.map((id) => ({
      id,
      name: t(`CONVERSATION.PRIORITY.OPTIONS.${id.toUpperCase()}`),
    }))

    const filterTypes: FilterType[] = [
      type('status', 'STATUS', EQUALITY, {
        options: STATUSES.map((id) => ({
          id,
          name: t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${id}.TEXT`),
        })),
      }),
      type('priority', 'PRIORITY', EQUALITY, { options: priorities }),
      type('assignee_id', 'ASSIGNEE_NAME', PRESENCE, {
        options: agents.map((agent) => ({ id: agent.id, name: agent.name })),
      }),
      type('inbox_id', 'INBOX_NAME', PRESENCE, {
        options: inboxes.map((inbox) => ({
          id: inbox.id,
          name: inbox.name,
          icon: channelIconName(inbox.channel_type),
        })),
      }),
      // o emoji do time (team.icon) não é desenhado: só há ícones Phosphor
      type('team_id', 'TEAM_NAME', PRESENCE, {
        options: teams.map((team) => ({ id: team.id, name: team.name })),
      }),
      type('contact_id', 'CONTACT', EQUALITY, {
        searchOptions: searchContacts,
        searchPlaceholder: t('FILTER.CONTACT_SEARCH_PLACEHOLDER'),
      }),
      type('display_id', 'CONVERSATION_IDENTIFIER', CONTAINMENT),
      // campanhas ainda não têm endpoint: o atributo existe, mas sem opções
      type('campaign_id', 'CAMPAIGN_NAME', PRESENCE, { options: [] }),
      type('labels', 'LABELS', PRESENCE, {
        options: labels.map((label) => ({
          id: label.title,
          name: label.title,
          color: label.color,
        })),
      }),
      type('browser_language', 'BROWSER_LANGUAGE', EQUALITY, {
        options: LANGUAGES,
        attributeModel: 'additional',
      }),
      type('referer', 'REFERER_LINK', CONTAINMENT, { attributeModel: 'additional' }),
      type('created_at', 'CREATED_AT', DATES),
      type('last_activity_at', 'LAST_ACTIVITY', DATES),
      // atributos personalizados entram com o endpoint de custom_attribute_definitions (Marco 6.4)
    ]

    // groupFilterTypes: cabeçalhos de grupo (não clicáveis) antes dos atributos de cada grupo
    const attributeOptions: SelectOption[] = GROUPS.flatMap(({ model, labelKey }) => {
      const group = filterTypes.filter((ft) => ft.attributeModel === model)
      if (!group.length) return []
      return [
        { value: `__group_${model}`, label: t(`FILTER.GROUPS.${labelKey}`), disabled: true },
        ...group.map((ft) => ({ value: ft.attributeKey, label: ft.label, icon: ft.icon })),
      ]
    })

    const lists: FilterLists = { agents, inboxes, teams, labels, languages: LANGUAGES, priorities }
    return { filterTypes, attributeOptions, lists }
  }, [t, agents, inboxes, teams, labels, searchContacts])
}
