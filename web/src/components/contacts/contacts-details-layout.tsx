// Port de components-next/Contacts/ContactsDetailsLayout.vue: cabeçalho (breadcrumb, bloquear, enviar mensagem),
// conteúdo central e painel lateral (fixo no desktop, gaveta no mobile).
// Fora do v1: o VoiceCallButton (chamadas de voz). "Send message" abre o ComposeConversation, que chega com a
// nova conversa: por ora o botão é só visual.
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { Breadcrumb } from '../next/breadcrumb'
import { Button } from '../next/button'
import { cx } from '../next/cx'

type Props = {
  contactName?: string
  blocked?: boolean
  isUpdating?: boolean
  onGoToContactsList: () => void
  onToggleBlock: (blocked: boolean) => void
  children: ReactNode
  sidebarHeader?: ReactNode
  sidebar?: ReactNode
}

export function ContactsDetailsLayout({
  contactName,
  blocked = false,
  isUpdating = false,
  onGoToContactsList,
  onToggleBlock,
  children,
  sidebarHeader,
  sidebar,
}: Props) {
  const { t } = useTranslation()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const toggleRef = useRef<HTMLDivElement>(null)
  const contentRef = useRef<HTMLDivElement>(null)

  // v-on-click-outside no botão da gaveta, ignorando o próprio conteúdo da gaveta
  useEffect(() => {
    if (!sidebarOpen) return
    const onClick = (event: MouseEvent) => {
      const target = event.target as Node
      if (toggleRef.current?.contains(target) || contentRef.current?.contains(target)) return
      setSidebarOpen(false)
    }
    document.addEventListener('click', onClick)
    return () => document.removeEventListener('click', onClick)
  }, [sidebarOpen])

  const breadcrumb = [
    { label: t('CONTACTS_LAYOUT.HEADER.BREADCRUMB.CONTACTS') },
    ...(contactName ? [{ label: contactName }] : []),
  ]

  return (
    <section className="flex h-full w-full justify-evenly overflow-hidden bg-n-surface-1">
      <div className="flex h-full w-full flex-col transition-all duration-300 ltr:2xl:ml-56 rtl:2xl:mr-56">
        <header className="3xl:px-0 sticky top-0 z-10 px-6">
          <div className="mx-auto w-full max-w-[40.625rem]">
            <div className="xs:flex-row xs:items-center flex w-full flex-col items-start justify-between gap-2 py-7">
              <Breadcrumb
                items={breadcrumb}
                ariaLabel={t('BREADCRUMB.ARIA_LABEL')}
                onItemClick={onGoToContactsList}
              />
              <div className="flex items-center gap-2">
                <Button
                  label={
                    blocked
                      ? t('CONTACTS_LAYOUT.HEADER.UNBLOCK_CONTACT')
                      : t('CONTACTS_LAYOUT.HEADER.BLOCK_CONTACT')
                  }
                  size="sm"
                  color="slate"
                  isLoading={isUpdating}
                  disabled={isUpdating}
                  onClick={() => onToggleBlock(blocked)}
                />
                <Button label={t('CONTACTS_LAYOUT.HEADER.SEND_MESSAGE')} size="sm" />
              </div>
            </div>
          </div>
        </header>
        <main className="3xl:px-px flex-1 overflow-y-auto px-6">
          <div className="mx-auto w-full max-w-[40.625rem] py-4">{children}</div>
        </main>
      </div>

      {sidebar && (
        <>
          <aside className="hidden w-full min-w-52 max-w-md flex-col border-l border-n-weak bg-n-solid-2 lg:flex">
            <div className="shrink-0">{sidebarHeader}</div>
            <div className="min-h-0 flex-1 overflow-y-auto pb-6 pt-3">{sidebar}</div>
          </aside>

          <div
            className={cx(
              'fixed top-0 z-50 flex h-full justify-end transition-all duration-200 ease-in-out ltr:right-0 rtl:left-0 lg:hidden',
              sidebarOpen ? 'w-full' : 'w-16',
            )}
          >
            <div
              ref={toggleRef}
              className={cx(
                'xs:top-24 relative top-28 order-1 flex h-fit w-fit items-start border border-n-weak bg-n-solid-2 p-1 transition-all duration-500 ease-in-out',
                sidebarOpen
                  ? 'justify-end ltr:rounded-l-full ltr:rounded-r-none rtl:rounded-l-none rtl:rounded-r-full'
                  : 'justify-center rounded-full ltr:mr-6 rtl:ml-6',
              )}
            >
              <Button
                variant="ghost"
                color="slate"
                size="sm"
                icon="ph-sidebar-simple"
                className={cx('!rounded-full rtl:rotate-180', sidebarOpen && 'bg-n-alpha-2')}
                onClick={() => setSidebarOpen((o) => !o)}
              />
            </div>
            {sidebarOpen && (
              <div
                ref={contentRef}
                className="order-2 flex w-[85%] flex-col border-n-weak bg-n-solid-2 shadow-lg sm:w-[50%] ltr:border-l rtl:border-r"
              >
                <div className="shrink-0">{sidebarHeader}</div>
                <div className="min-h-0 flex-1 overflow-y-auto pb-6 pt-3">{sidebar}</div>
              </div>
            )}
          </div>
        </>
      )}
    </section>
  )
}
