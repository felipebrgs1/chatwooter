// Porta de components/widgets/WootWriter/EditorModeToggle.vue: pílula Reply / Private Note.
import { useTranslation } from 'react-i18next'

import { cx } from '../next/cx'

export type ComposerMode = 'reply' | 'note'

type Props = {
  mode: ComposerMode
  onChange: (mode: ComposerMode) => void
  /** Sem janela de resposta: só nota privada */
  replyRestricted?: boolean
}

export function ComposerModeToggle({ mode, onChange, replyRestricted = false }: Props) {
  const { t } = useTranslation()
  const options: { value: ComposerMode; label: string }[] = [
    { value: 'reply', label: t('CONVERSATION.REPLYBOX.REPLY') },
    { value: 'note', label: t('CONVERSATION.REPLYBOX.PRIVATE_NOTE') },
  ]
  return (
    <div
      role="group"
      className="relative z-0 flex h-8 w-auto items-center rounded-full border bg-n-alpha-2 p-1"
    >
      {options.map(({ value, label }) => (
        <button
          key={value}
          type="button"
          aria-pressed={mode === value}
          disabled={replyRestricted}
          onClick={() => onChange(value)}
          className={cx(
            'z-20 flex h-6 items-center gap-1 rounded-full px-2 transition-all duration-300 ease-in-out',
            mode === value && 'bg-n-solid-1 shadow-sm',
            replyRestricted && 'cursor-not-allowed',
          )}
        >
          {label}
        </button>
      ))}
    </div>
  )
}
