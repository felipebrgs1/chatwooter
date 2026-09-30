// Port de components-next/Companies/CompaniesDetailsLayout.vue.
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Breadcrumb } from '../next/breadcrumb'
import { Button } from '../next/button'
import { cx } from '../next/cx'
export function CompaniesDetailsLayout({
  name,
  onBack,
  children,
  sidebarHeader,
  sidebar,
}: {
  name?: string
  onBack: () => void
  children: ReactNode
  sidebarHeader: ReactNode
  sidebar: ReactNode
}) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!open) return
    const close = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('click', close)
    return () => document.removeEventListener('click', close)
  }, [open])
  const panel = (
    <>
      <div className="shrink-0">{sidebarHeader}</div>
      <div className="min-h-0 flex-1 overflow-y-auto pb-6 pt-3">{sidebar}</div>
    </>
  )
  return (
    <section className="flex w-full h-full overflow-hidden justify-evenly bg-n-surface-1">
      <div className="flex flex-col w-full h-full transition-all duration-300 ltr:2xl:ml-56 rtl:2xl:mr-56">
        <header className="sticky top-0 z-10 px-6 3xl:px-0">
          <div className="w-full mx-auto max-w-[40.625rem]">
            <div className="flex items-center justify-between w-full py-7 gap-2">
              <Breadcrumb
                items={[{ label: t('COMPANIES.HEADER') }, ...(name ? [{ label: name }] : [])]}
                ariaLabel={t('BREADCRUMB.ARIA_LABEL')}
                onItemClick={onBack}
              />
            </div>
          </div>
        </header>
        <main className="flex-1 px-6 overflow-y-auto 3xl:px-px">
          <div className="w-full py-4 mx-auto max-w-[40.625rem]">{children}</div>
        </main>
      </div>
      <aside className="hidden lg:flex flex-col min-w-52 w-full max-w-md border-l border-n-weak bg-n-solid-2">
        {panel}
      </aside>
      <div
        ref={ref}
        className={cx(
          'lg:hidden fixed top-0 ltr:right-0 rtl:left-0 h-full z-50 flex justify-end transition-all duration-200 ease-in-out',
          open ? 'w-full' : 'w-16',
        )}
      >
        <div
          className={cx(
            'flex items-start p-1 w-fit h-fit relative order-1 top-28 transition-all bg-n-solid-2 border border-n-weak duration-500 ease-in-out',
            open
              ? 'justify-end ltr:rounded-l-full rtl:rounded-r-full'
              : 'justify-center rounded-full ltr:mr-6 rtl:ml-6',
          )}
        >
          <Button
            variant="ghost"
            color="slate"
            size="sm"
            icon="ph-sidebar-simple"
            aria-label={t('KEYBOARD_SHORTCUTS.TITLE.TOGGLE_SIDEBAR')}
            aria-expanded={open}
            className="!rounded-full"
            onClick={() => setOpen(!open)}
          />
        </div>
        {open && (
          <div className="order-2 w-[85%] sm:w-[50%] flex flex-col bg-n-solid-2 ltr:border-l rtl:border-r border-n-weak shadow-lg">
            {panel}
          </div>
        )}
      </div>
    </section>
  )
}
