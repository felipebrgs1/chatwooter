import { useEffect, useState } from 'react'

/** Hora atual, atualizada a cada `intervalMs`: faz o "time ago" dos cards se atualizar sozinho. */
export function useNow(intervalMs = 60_000) {
  const [now, setNow] = useState(() => new Date())

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), intervalMs)
    return () => clearInterval(id)
  }, [intervalMs])

  return now
}
