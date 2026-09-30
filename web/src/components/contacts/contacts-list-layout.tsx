// Port de components-next/Contacts/ContactsListLayout.vue (sem filtros ativos nem "carregar mais" da busca).
import type { ReactNode } from 'react'

import { PaginationFooter } from '../next/pagination-footer'

type Props = {
  header: ReactNode
  showPagination: boolean
  currentPage: number
  totalItems: number
  itemsPerPage: number
  onPageChange: (page: number) => void
  children: ReactNode
}

export function ContactsListLayout({
  header,
  showPagination,
  currentPage,
  totalItems,
  itemsPerPage,
  onPageChange,
  children,
}: Props) {
  return (
    <section className="flex h-full w-full justify-evenly gap-4 overflow-hidden bg-n-surface-1">
      <div className="flex h-full w-full flex-col transition-all duration-300">
        {header}
        <main className="flex-1 overflow-y-auto px-6">
          <div className="mx-auto w-full max-w-5xl">{children}</div>
        </main>
        {showPagination && (
          <footer className="sticky bottom-0 z-0">
            <PaginationFooter
              currentPageInfo="CONTACTS_LAYOUT.PAGINATION_FOOTER.SHOWING"
              currentPage={currentPage}
              totalItems={totalItems}
              itemsPerPage={itemsPerPage}
              className="max-w-[67rem]"
              onPageChange={onPageChange}
            />
          </footer>
        )}
      </div>
    </section>
  )
}
