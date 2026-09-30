// Porta de messageTimestamp(createdAt, 'LLL d, h:mm a') de shared/helpers/timeHelper.js.
export function messageTimestamp(epochSeconds: number, locale = 'en', timeZone?: string) {
  return new Intl.DateTimeFormat(locale.replace('_', '-'), {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZone,
  })
    .format(new Date(epochSeconds * 1000))
    .replace(/ /g, ' ') // ICU recente usa espaço fino antes de AM/PM
}
