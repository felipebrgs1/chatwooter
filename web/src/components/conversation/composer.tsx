// Porta enxuta de components/widgets/conversation/ReplyBox.vue (texto puro; editor rich text, canned, anexos etc. ficam para depois).
import { useLayoutEffect, useRef, useState, type KeyboardEvent } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '../next/button'
import { cx } from '../next/cx'
import { ComposerModeToggle, type ComposerMode } from './composer-mode-toggle'

type Props = {
  canReply: boolean
  onSend: (content: string, isPrivate: boolean) => void
}

export function Composer({ canReply, onSend }: Props) {
  const { t } = useTranslation()
  const [chosen, setChosen] = useState<ComposerMode>('reply')
  const [text, setText] = useState('')
  const field = useRef<HTMLTextAreaElement>(null)
  // Sem can_reply só dá para deixar nota privada (o toggle fica travado nela)
  const mode: ComposerMode = canReply ? chosen : 'note'
  const isNote = mode === 'note'
  const empty = text.trim() === ''

  // O campo cresce com o conteúdo (o max-h do CSS limita)
  useLayoutEffect(() => {
    const el = field.current
    if (!el) return
    el.style.height = 'auto'
    el.style.height = `${el.scrollHeight}px`
  }, [text])

  function submit() {
    if (empty) return
    onSend(text.trim(), isNote)
    setText('')
  }

  function onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key !== 'Enter' || event.shiftKey || event.nativeEvent.isComposing) return
    event.preventDefault()
    submit()
  }

  return (
    <>
      {!canReply && (
        <div className="mx-2 mt-2 flex items-center overflow-hidden rounded-lg bg-n-ruby-3 px-4 py-2 text-sm text-n-ruby-12">
          {t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED')}
        </div>
      )}
      <div
        className={cx(
          'relative mx-2 mb-2 rounded-xl border',
          isNote
            ? 'border-n-amber-12/5 bg-n-solid-amber dark:border-n-amber-3/10'
            : 'border-n-weak bg-n-solid-1',
        )}
      >
        <div className="flex h-[3.25rem] items-center justify-between gap-2 pl-3 pr-2">
          <ComposerModeToggle mode={mode} onChange={setChosen} replyRestricted={!canReply} />
        </div>
        <div className="relative -mt-px px-3 py-0">
          <textarea
            ref={field}
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={onKeyDown}
            rows={1}
            placeholder={t(
              isNote ? 'CONVERSATION.FOOTER.PRIVATE_MSG_INPUT' : 'CONVERSATION.FOOTER.MSG_INPUT',
            )}
            className="block max-h-60 min-h-16 w-full resize-none overflow-y-auto border-0 bg-transparent p-0 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10"
          />
        </div>
        <div className="flex justify-between p-3">
          <div className="flex items-center gap-2" />
          <div className="flex">
            <Button
              type="submit"
              size="sm"
              color={isNote ? 'amber' : 'blue'}
              label={t(isNote ? 'CONVERSATION.REPLYBOX.CREATE' : 'CONVERSATION.REPLYBOX.SEND')}
              disabled={empty}
              onClick={submit}
              className="flex-shrink-0"
            />
          </div>
        </div>
      </div>
    </>
  )
}
