// Equivale ao hook .SearchableList do app antigo (filtro local de ComboBox/DropdownMenu do Chatwoot):
// filtra por texto sem diferenciar caixa; com busca ativa os cabeçalhos de grupo somem.
import type { ReactNode } from 'react'

import { useSearchableList, type SearchableListState } from './use-searchable-list'

type Props<T> = {
  items: T[]
  getText: (item: T) => string
  isHeader?: (item: T) => boolean
  className?: string
  children: (state: SearchableListState<T>) => ReactNode
}

export function SearchableList<T>({ items, getText, isHeader, className, children }: Props<T>) {
  const state = useSearchableList(items, getText, isHeader)
  return <div className={className}>{children(state)}</div>
}
