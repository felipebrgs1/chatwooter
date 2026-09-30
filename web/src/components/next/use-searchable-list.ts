// Filtro local de listas com busca (equivale ao hook .SearchableList do app antigo).
import { useMemo, useState } from 'react'

export type SearchableListState<T> = {
  query: string
  setQuery: (query: string) => void
  visible: T[]
  /** Há busca e nada casou. */
  isEmpty: boolean
}

export function useSearchableList<T>(
  items: T[],
  getText: (item: T) => string,
  isHeader: (item: T) => boolean = () => false,
): SearchableListState<T> {
  const [query, setQuery] = useState('')
  return useMemo(() => {
    const needle = query.trim().toLowerCase()
    if (!needle) return { query, setQuery, visible: items, isEmpty: false }
    const visible = items.filter((i) => !isHeader(i) && getText(i).toLowerCase().includes(needle))
    return { query, setQuery, visible, isEmpty: visible.length === 0 }
  }, [query, items, getText, isHeader])
}
