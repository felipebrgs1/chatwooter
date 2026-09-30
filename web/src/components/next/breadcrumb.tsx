// Port de components-next/breadcrumb/Breadcrumb.vue. Usa <a href> em vez de router-link: o app
// decide a navegação (o roteador intercepta links internos).
import { cx } from './cx'
import { Icon } from './icon'

export type BreadcrumbItem = { label: string; href?: string }

type Props = {
  items: BreadcrumbItem[]
  ariaLabel: string
  id?: string
}

export function Breadcrumb({ items, ariaLabel, id }: Props) {
  return (
    <nav id={id} aria-label={ariaLabel} className="flex items-center h-8 min-w-0">
      <ol className="flex items-center mb-0 min-w-0">
        {items.map((item, index) => {
          const last = index === items.length - 1
          return (
            <li
              key={`${index}-${item.label}`}
              className={cx('flex items-center', last && 'min-w-0 flex-1')}
            >
              {index > 0 && (
                <Icon name="ph-caret-right" className="flex-shrink-0 mx-2 size-4 text-n-slate-11" />
              )}
              {last ? (
                <span
                  aria-current="page"
                  className="inline-flex items-center gap-1 text-sm truncate min-w-0"
                >
                  <span className="truncate text-n-slate-12">{item.label}</span>
                </span>
              ) : (
                <a
                  href={item.href}
                  className="inline-flex items-center justify-center min-w-0 gap-2 p-0 text-sm font-medium transition-all duration-200 ease-in-out border-0 rounded-lg text-n-slate-11 hover:text-n-slate-12 outline-transparent max-w-56"
                >
                  <span className="min-w-0 truncate">{item.label}</span>
                </a>
              )}
            </li>
          )
        })}
      </ol>
    </nav>
  )
}
