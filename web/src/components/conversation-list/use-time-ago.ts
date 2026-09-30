// Port de components/ui/TimeAgo.vue: conversas antigas não precisam atualizar a cada minuto.
import { useEffect, useState } from 'react'

const MINUTE = 60_000
const HOUR = MINUTE * 60
const DAY = HOUR * 24

export function useTimeAgo(lastActivity: number, conversationId: number): Date {
  const [now, setNow] = useState(() => new Date())

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout>
    const schedule = () => {
      const age = Date.now() - lastActivity * 1000
      timer = setTimeout(
        () => {
          setNow(new Date())
          schedule()
        },
        age > DAY ? DAY : age > HOUR ? HOUR : MINUTE,
      )
    }
    setNow(new Date())
    schedule()
    return () => clearTimeout(timer)
  }, [lastActivity, conversationId])

  return now
}
