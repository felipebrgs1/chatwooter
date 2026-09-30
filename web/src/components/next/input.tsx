// Port de components-next/input/Input.vue.
import { useId, type InputHTMLAttributes, type ReactNode } from 'react'

import { cx } from './cx'

type MessageType = 'info' | 'error' | 'success'

type Props = Omit<InputHTMLAttributes<HTMLInputElement>, 'size' | 'prefix'> & {
  label?: string
  size?: 'sm' | 'md'
  message?: string
  messageType?: MessageType
  inputClassName?: string
  className?: string
  /** Slot `prefix`: ícone posicionado sobre o campo (ex.: lupa da busca). */
  prefix?: ReactNode
}

const messageColors: Record<MessageType, string> = {
  error: 'text-n-ruby-9',
  success: 'text-n-teal-10',
  info: 'text-n-slate-11',
}

export function Input({
  id,
  label,
  size = 'md',
  message,
  messageType = 'info',
  inputClassName,
  className,
  type = 'text',
  prefix,
  ...rest
}: Props) {
  const generated = useId()
  const inputId = id ?? generated
  const messageId = `${inputId}-message`
  const invalid = messageType === 'error'

  return (
    <div className={cx('relative flex flex-col min-w-0 gap-1', className)}>
      {label && (
        <label htmlFor={inputId} className="mb-0.5 text-heading-3 text-n-slate-12">
          {label}
        </label>
      )}
      {prefix}
      <input
        id={inputId}
        type={type}
        aria-invalid={invalid ? true : undefined}
        aria-describedby={message ? messageId : undefined}
        className={cx(
          'block w-full text-sm mb-0! outline outline-1 border-none border-0 outline-offset-[-1px] rounded-lg bg-n-alpha-black2 text-ellipsis placeholder:text-n-slate-10 disabled:cursor-not-allowed disabled:opacity-50 text-n-slate-12 transition-all duration-500 ease-in-out [appearance:textfield]',
          invalid
            ? 'outline-n-ruby-8 hover:outline-n-ruby-9'
            : 'outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand',
          size === 'sm' ? 'h-8 px-3! py-2!' : 'h-10 px-3! py-2.5!',
          inputClassName,
        )}
        {...rest}
      />
      {message && (
        <p
          id={messageId}
          className={cx(
            'min-w-0 mt-1 mb-0 text-label-small truncate transition-all duration-500 ease-in-out',
            messageColors[messageType],
          )}
        >
          {message}
        </p>
      )}
    </div>
  )
}
