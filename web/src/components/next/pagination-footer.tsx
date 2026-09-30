// Port de components-next/pagination/PaginationFooter.vue.
import { useTranslation } from 'react-i18next'

import { Button } from './button'

type Props = {
  currentPage: number
  totalItems: number
  itemsPerPage?: number
  /** Chave i18n do "Showing x - y of z" (cada lista tem a sua). */
  currentPageInfo?: string
  className?: string
  onPageChange: (page: number) => void
}

// useNumberFormatter: número inteiro com separador do idioma; o total em forma compacta (1.2K)
const full = (n: number, locale: string) => new Intl.NumberFormat(locale).format(n)
const compact = (n: number, locale: string) =>
  new Intl.NumberFormat(locale, { notation: 'compact', maximumFractionDigits: 1 }).format(n)

export function PaginationFooter({
  currentPage,
  totalItems,
  itemsPerPage = 16,
  currentPageInfo,
  className,
  onPageChange,
}: Props) {
  const { t, i18n } = useTranslation()
  const locale = i18n.language.replace('_', '-')
  const totalPages = Math.ceil(totalItems / itemsPerPage)
  const startItem = (currentPage - 1) * itemsPerPage + 1
  const endItem = Math.min(startItem + itemsPerPage - 1, totalItems)
  const isFirstPage = currentPage === 1
  const isLastPage = currentPage === totalPages
  const changePage = (page: number) => {
    if (page >= 1 && page <= totalPages) onPageChange(page)
  }

  const showing = t(currentPageInfo ?? 'PAGINATION_FOOTER.SHOWING', {
    startItem: full(startItem, locale),
    endItem: full(endItem, locale),
    totalItems: compact(totalItems, locale),
    count: totalItems,
  })
  const pageInfo = t('PAGINATION_FOOTER.CURRENT_PAGE_INFO', {
    currentPage: '',
    totalPages: compact(totalPages, locale),
    count: totalPages,
  })
  const nav = 'h-6! w-8!'

  return (
    <div
      className={`mx-auto flex h-[3.375rem] w-full items-center justify-between border-t border-n-weak bg-n-surface-1 px-6 py-3 before:pointer-events-none before:absolute before:inset-x-0 before:-top-4 before:h-4 before:bg-gradient-to-t before:from-n-surface-1 before:from-0% before:to-transparent ${className ?? ''}`}
    >
      <div className="flex items-center gap-3">
        <span className="line-clamp-1 min-w-0 text-body-main text-n-slate-11">{showing}</span>
      </div>
      <div className="flex items-center gap-2">
        <Button
          icon="ph-caret-double-left"
          variant="ghost"
          size="sm"
          color="slate"
          className={nav}
          disabled={isFirstPage}
          onClick={() => changePage(1)}
        />
        <Button
          icon="ph-caret-left"
          variant="ghost"
          size="sm"
          color="slate"
          className={nav}
          disabled={isFirstPage}
          onClick={() => changePage(currentPage - 1)}
        />
        <div className="inline-flex items-center gap-2 text-sm">
          <span className="rounded-md bg-n-input-background px-3 py-0.5 text-body-main font-[420] tabular-nums text-n-slate-12">
            {full(currentPage, locale)}
          </span>
          <span className="truncate text-body-main text-n-slate-11">{pageInfo}</span>
        </div>
        <Button
          icon="ph-caret-right"
          variant="ghost"
          size="sm"
          color="slate"
          className={nav}
          disabled={isLastPage}
          onClick={() => changePage(currentPage + 1)}
        />
        <Button
          icon="ph-caret-double-right"
          variant="ghost"
          size="sm"
          color="slate"
          className={nav}
          disabled={isLastPage}
          onClick={() => changePage(totalPages)}
        />
      </div>
    </div>
  )
}
