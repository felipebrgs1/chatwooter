import { useCallback, useState, type SetStateAction } from 'react'

// Estado guardado em localStorage; se o armazenamento estiver bloqueado, vale só na sessão.
export function usePersistedState<T>(key: string, initial: T) {
  const [value, setValue] = useState<T>(() => {
    try {
      const stored = localStorage.getItem(key)
      return stored === null ? initial : (JSON.parse(stored) as T)
    } catch {
      return initial
    }
  })

  const set = useCallback(
    (next: SetStateAction<T>) => {
      setValue((current) => {
        const resolved = typeof next === 'function' ? (next as (c: T) => T)(current) : next
        try {
          localStorage.setItem(key, JSON.stringify(resolved))
        } catch {
          // sem armazenamento: segue só em memória
        }
        return resolved
      })
    },
    [key],
  )

  return [value, set] as const
}
