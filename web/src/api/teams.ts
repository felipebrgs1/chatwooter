// Times da conta: api/v1/accounts/teams_controller.rb (só o index por ora).
import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { Team } from './types'

export const teamsQuery = (accountId: number) =>
  queryOptions({
    queryKey: ['accounts', accountId, 'teams'],
    queryFn: () => api.get<Team[]>(`/api/v1/accounts/${accountId}/teams`),
    staleTime: 5 * 60 * 1000,
  })
