// Port de components-next/avatar/Avatar.vue + helpers de nome/iniciais.
import { useState } from 'react'
import { cx } from './cx'
import { Icon } from './icon'
import { initials } from './initials'

// Avatar.vue: a cor vem do tamanho do nome (AVATAR_COLORS); tokens em tokens.css
const avatarColors = [
  'bg-avatar-0-bg text-avatar-0-text',
  'bg-avatar-1-bg text-avatar-1-text',
  'bg-avatar-2-bg text-avatar-2-text',
  'bg-avatar-3-bg text-avatar-3-text',
  'bg-avatar-4-bg text-avatar-4-text',
  'bg-avatar-5-bg text-avatar-5-text',
]

const statusColors = {
  online: 'bg-n-teal-10',
  busy: 'bg-n-amber-10',
  offline: 'bg-n-slate-10',
} as const

export type AvatarStatus = keyof typeof statusColors

function radius(size: number) {
  if (size <= 16) return 'rounded'
  if (size <= 24) return 'rounded-md'
  if (size <= 32) return 'rounded-lg'
  if (size <= 48) return 'rounded-xl'
  return 'rounded-2xl'
}

type Props = {
  src?: string | null
  name?: string | null
  size?: number
  status?: AvatarStatus | null
  className?: string
}

export function Avatar({ src, name, size = 32, status = null, className }: Props) {
  const [failedSource, setFailedSource] = useState<string | null>(null)
  const showImage = !!src && src !== failedSource
  const color = name ? avatarColors[name.length % avatarColors.length] : null
  const badge = Math.max(size * 0.35, 8)
  const badgeOffset = size - badge / 1.1

  return (
    <span
      className={cx('relative inline-flex group/avatar z-0 flex-shrink-0 align-middle', className)}
      style={{ width: size, height: size }}
    >
      {status && (
        <span
          data-status={status}
          className={cx('absolute z-20 border rounded-full border-n-slate-3', statusColors[status])}
          style={{ width: badge, height: badge, top: badgeOffset, left: badgeOffset }}
        />
      )}
      <span
        role="img"
        aria-label={name ?? undefined}
        className={cx(
          'relative inline-flex items-center justify-center object-cover overflow-hidden font-medium outline outline-1 -outline-offset-1 outline-black/3 dark:outline-white/4',
          radius(size),
          color ?? 'bg-n-slate-3 dark:bg-n-slate-4',
        )}
        style={{ width: size, height: size }}
      >
        {showImage ? (
          <img
            src={src!}
            alt=""
            className="size-full object-cover"
            onError={() => setFailedSource(src!)}
          />
        ) : color && name ? (
          <span className="select-none" style={{ fontSize: Math.min(size / 2.5, 24) }}>
            {initials(name)}
          </span>
        ) : (
          <span style={{ fontSize: size / 1.6 }} className="inline-flex">
            <Icon name="ph-user" />
          </span>
        )}
      </span>
    </span>
  )
}
