// Port de components-next/flag/Flag.vue: bandeira do pacote flag-icons (o mesmo do Chatwoot).
import 'flag-icons/css/flag-icons.min.css'

import { cx } from './cx'

type Props = { country: string; squared?: boolean; className?: string }

export function Flag({ country, squared = false, className }: Props) {
  return (
    <span
      aria-hidden="true"
      className={cx(
        'fi',
        `fi-${country.toLowerCase()}`,
        'flex-shrink-0',
        squared && 'fis',
        className,
      )}
    />
  )
}
