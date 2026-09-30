// Inboxes da conta: api/v1/accounts/inboxes_controller.rb (só o index por ora).
import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { Inbox } from './types'

// O servidor já filtra pelo papel (agente só vê as suas inboxes).
export const inboxesQuery = (accountId: number) =>
  queryOptions({
    queryKey: ['accounts', accountId, 'inboxes'],
    queryFn: () => api.get<{ payload: Inbox[] }>(`/api/v1/accounts/${accountId}/inboxes`),
    select: (data) => data.payload,
    staleTime: 5 * 60 * 1000,
  })
