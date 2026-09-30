// Tempo relativo como no Chatwoot (shared/helpers/timeHelper.js): `dynamicTime` usa
// formatDistanceToNow do date-fns (en-US, sem segundos) e `shortTimestamp` o abrevia ("5h", "3d").
const MINUTES_IN_DAY = 1440
const MINUTES_IN_MONTH = 43_200

const plural = (n: number, unit: string) => `${n} ${unit}${n === 1 ? '' : 's'}`

function calendarMonths(from: Date, to: Date) {
  const months = (to.getFullYear() - from.getFullYear()) * 12 + (to.getMonth() - from.getMonth())
  const dayTime = (d: Date) =>
    d.getDate() * 1e6 + d.getHours() * 1e4 + d.getMinutes() * 1e2 + d.getSeconds()
  return dayTime(to) < dayTime(from) ? months - 1 : months
}

function distance(from: Date, now: Date) {
  const minutes = Math.round((now.getTime() - from.getTime()) / 60_000)

  if (minutes < MINUTES_IN_DAY) {
    if (minutes < 1) return 'less than a minute'
    if (minutes < 2) return '1 minute'
    if (minutes < 45) return `${minutes} minutes`
    if (minutes < 90) return 'about 1 hour'
    return `about ${Math.round(minutes / 60)} hours`
  }
  if (minutes < 2520) return '1 day'
  if (minutes < MINUTES_IN_MONTH) return `${Math.round(minutes / MINUTES_IN_DAY)} days`
  if (minutes < 2 * MINUTES_IN_MONTH)
    return `about ${plural(Math.round(minutes / MINUTES_IN_MONTH), 'month')}`

  const months = calendarMonths(from, now)
  if (months < 12) return plural(Math.round(minutes / MINUTES_IN_MONTH), 'month')
  const years = Math.floor(months / 12)
  const rest = months % 12
  if (rest < 3) return `about ${plural(years, 'year')}`
  if (rest < 9) return `over ${plural(years, 'year')}`
  return `almost ${plural(years + 1, 'year')}`
}

/** `timestamp` em segundos (como a API do Chatwoot); vazio quando não há. */
export function longTimeAgo(timestamp: number | null | undefined, now: Date = new Date()) {
  if (!timestamp) return ''
  return `${distance(new Date(timestamp * 1000), now)} ago`
}

const unitSuffix = { minute: 'm', hour: 'h', day: 'd', month: 'mo', year: 'y' } as const

export function shortTimeAgo(timestamp: number | null | undefined, now: Date = new Date()) {
  const long = longTimeAgo(timestamp, now)
  if (!long) return ''
  if (long === 'less than a minute ago') return 'now'
  return long
    .replace(/about|over|almost/, '')
    .replace(/ (minute|hour|day|month|year)s? ago$/, (match) => {
      const unit = match.trim().split(' ')[0].replace(/s$/, '') as keyof typeof unitSuffix
      return unitSuffix[unit]
    })
    .trim()
}

/** Tooltip de data/hora exata (useExactTimestamp): "Sep 30 2026, 3:04 PM". */
export function exactTimestamp(timestamp: number | null | undefined, timeZone?: string) {
  if (!timestamp) return ''
  const parts = new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone,
  }).formatToParts(new Date(timestamp * 1000))
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? ''
  return `${get('month')} ${get('day')} ${get('year')}, ${get('hour')}:${get('minute')} ${get('dayPeriod')}`
}
