// Agentes da conta: api/v1/accounts/agents_controller.rb (só o index por ora).
import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { Agent } from './types'

export const agentsQuery = (accountId: number) =>
  queryOptions({
    queryKey: ['accounts', accountId, 'agents'],
    queryFn: () => api.get<Agent[]>(`/api/v1/accounts/${accountId}/agents`),
    staleTime: 5 * 60 * 1000,
  })
