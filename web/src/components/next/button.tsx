// Port de components-next/button/Button.vue (STYLE_CONFIG).
import type { ButtonHTMLAttributes, ReactNode } from 'react'

import { cx } from './cx'
import { Icon } from './icon'
import { Spinner } from './spinner'

const colors = {
  blue: {
    solid:
      'bg-n-brand text-white hover:enabled:brightness-110 focus-visible:brightness-110 outline-transparent',
    faded:
      'bg-n-brand/10 text-n-blue-11 hover:enabled:bg-n-brand/20 focus-visible:bg-n-brand/20 outline-transparent',
    outline: 'text-n-blue-11 outline-n-brand',
    ghost:
      'text-n-blue-11 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent',
    link: 'text-n-blue-11 hover:enabled:underline focus-visible:underline outline-transparent',
  },
  ruby: {
    solid:
      'bg-n-ruby-9 text-white hover:enabled:bg-n-ruby-10 focus-visible:bg-n-ruby-10 outline-transparent',
    faded:
      'bg-n-ruby-9/10 text-n-ruby-11 hover:enabled:bg-n-ruby-9/20 focus-visible:bg-n-ruby-9/20 outline-transparent',
    outline:
      'text-n-ruby-11 hover:enabled:bg-n-ruby-9/10 focus-visible:bg-n-ruby-9/10 outline-n-ruby-8',
    ghost:
      'text-n-ruby-11 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent',
    link: 'text-n-ruby-9 dark:text-n-ruby-11 hover:enabled:underline focus-visible:underline outline-transparent',
  },
  amber: {
    solid:
      'bg-n-amber-9 text-n-amber-12 dark:text-n-amber-3 hover:enabled:bg-n-amber-10 focus-visible:bg-n-amber-10 outline-transparent',
    faded:
      'bg-n-amber-9/10 text-n-slate-12 hover:enabled:bg-n-amber-9/20 focus-visible:bg-n-amber-9/20 outline-transparent',
    outline:
      'text-n-amber-11 hover:enabled:bg-n-amber-9/10 focus-visible:bg-n-amber-9/10 outline-n-amber-9',
    ghost:
      'text-n-amber-9 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent',
    link: 'text-n-amber-9 hover:enabled:underline focus-visible:underline outline-transparent',
  },
  slate: {
    solid:
      'bg-n-button-color dark:hover:enabled:bg-n-solid-2 dark:focus-visible:bg-n-solid-2 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 text-n-slate-12 outline-n-container',
    faded:
      'bg-n-slate-9/10 text-n-slate-12 hover:enabled:bg-n-slate-9/20 focus-visible:bg-n-slate-9/20 outline-transparent',
    outline:
      'text-n-slate-11 outline-n-strong hover:enabled:bg-n-slate-9/10 focus-visible:bg-n-slate-9/10',
    ghost:
      'text-n-slate-12 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent',
    link: 'text-n-slate-11 hover:enabled:text-n-slate-12 focus-visible:text-n-slate-12 hover:enabled:underline focus-visible:underline outline-transparent',
  },
  teal: {
    solid:
      'bg-n-teal-9 text-white hover:enabled:bg-n-teal-10 focus-visible:bg-n-teal-10 outline-transparent',
    faded:
      'bg-n-teal-9/10 text-n-teal-11 hover:enabled:bg-n-teal-9/20 focus-visible:bg-n-teal-9/20 outline-transparent',
    outline:
      'text-n-teal-11 hover:enabled:bg-n-teal-9/10 focus-visible:bg-n-teal-9/10 outline-n-teal-9',
    ghost:
      'text-n-teal-9 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent',
    link: 'text-n-teal-9 hover:enabled:underline focus-visible:underline outline-transparent',
  },
} as const

const sizes = {
  regular: { xs: 'h-6 px-2', sm: 'h-8 px-3', md: 'h-10 px-4', lg: 'h-12 px-5' },
  iconOnly: { xs: 'h-6 w-6 p-0', sm: 'h-8 w-8 p-0', md: 'h-10 w-10 p-0', lg: 'h-12 w-12 p-0' },
} as const

const fontSizes = { xs: 'text-xs', sm: 'text-sm', md: 'text-sm font-medium', lg: 'text-base' }
const clickAnimation = {
  xs: 'active:enabled:scale-[0.97]',
  sm: 'active:enabled:scale-[0.97]',
  md: 'active:enabled:scale-[0.98]',
  lg: 'active:enabled:scale-[0.98]',
}
const justifyClasses = { start: 'justify-start', center: 'justify-center', end: 'justify-end' }

export type ButtonColor = keyof typeof colors
export type ButtonVariant = keyof (typeof colors)['blue']
export type ButtonSize = keyof typeof fontSizes

type Props = Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'color'> & {
  label?: string
  icon?: string
  trailingIcon?: boolean
  color?: ButtonColor
  variant?: ButtonVariant
  size?: ButtonSize
  justify?: keyof typeof justifyClasses
  noAnimation?: boolean
  /** Troca o ícone por um spinner, como o Button.vue. */
  isLoading?: boolean
  children?: ReactNode
}

export function Button({
  label,
  icon,
  trailingIcon = false,
  color = 'blue',
  variant = 'solid',
  size = 'md',
  justify = 'center',
  noAnimation = false,
  isLoading = false,
  type = 'button',
  className,
  children,
  ...rest
}: Props) {
  const iconOnly = !label && !children
  const sizeClasses =
    variant === 'link' ? 'p-0' : iconOnly ? sizes.iconOnly[size] : sizes.regular[size]

  return (
    <button
      type={type}
      className={cx(
        'inline-flex items-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline disabled:opacity-50',
        colors[color][variant],
        variant === 'link' && 'font-medium underline-offset-2',
        sizeClasses,
        fontSizes[size],
        !noAnimation && clickAnimation[size],
        justifyClasses[justify],
        trailingIcon && !iconOnly && 'flex-row-reverse',
        className,
      )}
      {...rest}
    >
      {icon && !isLoading && <Icon name={icon} className="flex-shrink-0" />}
      {isLoading && (
        <span className="inline-flex size-5 flex-shrink-0">
          <Spinner size={20} />
        </span>
      )}
      {label && <span className="min-w-0 truncate">{label}</span>}
      {children}
    </button>
  )
}
