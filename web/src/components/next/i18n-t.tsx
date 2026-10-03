// Equivale ao <I18nT> do vue-i18n: o texto traduzido com partes em JSX no lugar dos {placeholders}.
import { Fragment, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

type Props = {
  keypath: string
  /** Escolhe a forma "singular | plural". */
  plural?: number
  values: Record<string, ReactNode>
  className?: string
}

export function I18nT({ keypath, plural, values, className }: Props) {
  const { t } = useTranslation()
  // sem os valores nas opções, o pós-processador mantém os {placeholders} para trocarmos aqui
  const text = t(keypath, plural === undefined ? {} : { count: plural })
  const parts = text.split(/\{(\w+)\}/)
  return (
    <p className={className}>
      {parts.map((part, index) =>
        index % 2 === 1 && part in values ? <Fragment key={index}>{values[part]}</Fragment> : part,
      )}
    </p>
  )
}
