// Porta de v3/components/Form/Input.vue + WithLabel.vue. Os aria-label do botão de senha são fixos em inglês
// no original (não há chave no i18n).
import { Eye, EyeSlash } from '@phosphor-icons/react'
import { useId, useState, type InputHTMLAttributes, type ReactNode } from 'react'

import { cx } from '../next/cx'

type Props = Omit<InputHTMLAttributes<HTMLInputElement>, 'id' | 'name'> & {
  label: string
  name: string
  hasError?: boolean
  errorMessage?: string
  /** Conteúdo à direita do label (ex.: "Esqueceu a senha?"). */
  rightOfLabel?: ReactNode
}

export function FormInput({
  label,
  name,
  type = 'text',
  hasError = false,
  errorMessage,
  rightOfLabel,
  className,
  ...rest
}: Props) {
  const id = useId()
  const [visible, setVisible] = useState(false)
  const isPassword = type === 'password'

  return (
    <div className="space-y-1">
      <label
        htmlFor={id}
        className={cx(
          'flex justify-between text-sm font-medium leading-6 text-n-slate-12',
          hasError && 'text-n-ruby-12',
        )}
      >
        {label}
        {rightOfLabel}
      </label>
      <div className="w-full">
        <div className="relative flex w-full items-center">
          <input
            {...rest}
            id={id}
            name={name}
            type={isPassword && visible ? 'text' : type}
            className={cx(
              'block w-full appearance-none rounded-md border-none bg-n-alpha-black2 px-3 py-3 text-n-slate-12 shadow-sm outline outline-1 placeholder:text-n-slate-10 focus:outline focus:outline-1 sm:text-sm sm:leading-6',
              hasError
                ? 'error outline-n-ruby-8 hover:outline-n-ruby-9 dark:outline-n-ruby-8 dark:hover:outline-n-ruby-9'
                : 'outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand dark:outline-n-weak dark:hover:outline-n-slate-6 dark:focus:outline-n-brand',
              isPassword && 'pr-10',
              className,
            )}
          />
          {isPassword && (
            <button
              type="button"
              aria-label={visible ? 'Hide password' : 'Show password'}
              aria-pressed={visible}
              onClick={() => setVisible((v) => !v)}
              className="absolute inset-y-0 right-0 pr-3 text-n-slate-11 hover:text-n-slate-12"
            >
              {visible ? <EyeSlash className="size-4" /> : <Eye className="size-4" />}
            </button>
          )}
        </div>
        {hasError && errorMessage && (
          <div className="ml-px mt-1.5 text-sm leading-tight text-n-ruby-9">{errorMessage}</div>
        )}
      </div>
    </div>
  )
}
