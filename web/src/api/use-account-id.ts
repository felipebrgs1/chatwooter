import { useQuery } from '@tanstack/react-query'

import { profileQuery } from './auth'

/** Conta ativa do usuário logado (a área autenticada só existe com perfil carregado). */
export function useAccountId(): number {
  const { data } = useQuery(profileQuery)
  const accountId = data?.account_id ?? data?.accounts[0]?.id
  if (accountId === undefined) throw new Error('useAccountId fora da área autenticada')
  return accountId
}
