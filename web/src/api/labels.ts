// Etiquetas da conta: api/v1/accounts/labels_controller.rb (só o index por ora).
import { queryOptions } from '@tanstack/react-query'

import { api } from './client'
import type { Label } from './types'

// Mudam pouco e várias telas leem (sidebar, cards): uma busca por conta basta.
export const labelsQuery = (accountId: number) =>
  queryOptions({
    queryKey: ['accounts', accountId, 'labels'],
    queryFn: () => api.get<{ payload: Label[] }>(`/api/v1/accounts/${accountId}/labels`),
    select: (data) => data.payload,
    staleTime: 5 * 60 * 1000,
  })
