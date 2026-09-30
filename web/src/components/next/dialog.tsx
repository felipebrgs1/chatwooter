// Port de components-next/dialog/Dialog.vue. Portal + fundo em vez de <dialog> nativo: o jsdom não
// implementa showModal e o comportamento (Esc, clique no fundo, foco) fica igual e testável.
import { useEffect, useId, useRef, type FormEvent, type KeyboardEvent, type ReactNode } from 'react'
import { createPortal } from 'react-dom'

import { Button } from './button'
import { cx } from './cx'

type Props = {
  open: boolean
  onClose: () => void
  onConfirm: () => void
  title?: string
  description?: string
  type?: 'edit' | 'alert'
  confirmLabel: string
  cancelLabel: string
  width?: string
  children?: ReactNode
}

const focusable =
  'a[href], button:not([disabled]), input:not([disabled]), select, textarea, [tabindex]:not([tabindex="-1"])'

export function Dialog({
  open,
  onClose,
  onConfirm,
  title,
  description,
  type = 'edit',
  confirmLabel,
  cancelLabel,
  width = 'max-w-lg',
  children,
}: Props) {
  const titleId = useId()
  const panelRef = useRef<HTMLDivElement>(null)
  const onCloseRef = useRef(onClose)

  useEffect(() => {
    onCloseRef.current = onClose
  })

  useEffect(() => {
    if (!open) return
    const opener = document.activeElement as HTMLElement | null
    panelRef.current?.focus()
    const onKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key === 'Escape') onCloseRef.current()
    }
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('keydown', onKeyDown)
      opener?.focus()
    }
  }, [open])

  if (!open) return null

  function trapTab(event: KeyboardEvent) {
    if (event.key !== 'Tab' || !panelRef.current) return
    const items = Array.from(panelRef.current.querySelectorAll<HTMLElement>(focusable))
    if (items.length === 0) return
    const first = items[0]
    const last = items[items.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  function submit(event: FormEvent) {
    event.preventDefault()
    onConfirm()
    onClose()
  }

  return createPortal(
    <div
      data-testid="dialog-backdrop"
      onClick={(event) => event.target === event.currentTarget && onClose()}
      className="fixed inset-0 z-50 flex overflow-y-auto bg-n-alpha-black1 backdrop-blur-[4px]"
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? titleId : undefined}
        tabIndex={-1}
        onKeyDown={trapTab}
        className={cx(
          'w-full m-auto transition-all duration-300 ease-in-out shadow-xl rounded-xl bg-transparent overflow-visible focus:outline-none',
          width,
        )}
      >
        <form
          onSubmit={submit}
          className="flex flex-col w-full h-auto gap-6 p-6 overflow-visible text-start align-middle bg-n-alpha-3 backdrop-blur-[100px] shadow-xl rounded-xl"
        >
          {(title || description) && (
            <div className="flex flex-col gap-2">
              <h3 id={titleId} className="text-base font-medium leading-6 text-n-slate-12">
                {title}
              </h3>
              {description && <p className="mb-0 text-sm text-n-slate-11">{description}</p>}
            </div>
          )}
          {children}
          <div className="flex items-center justify-between w-full gap-3">
            <Button
              variant="faded"
              color="slate"
              label={cancelLabel}
              className="w-full"
              onClick={onClose}
            />
            <Button
              type="submit"
              color={type === 'edit' ? 'blue' : 'ruby'}
              label={confirmLabel}
              className="w-full"
            />
          </div>
        </form>
      </div>
    </div>,
    document.body,
  )
}
