// Port de components/widgets/ChatTypeTabs.vue (abas Mine / Unassigned / All) sobre woot-tabs compacto.
import { useTranslation } from 'react-i18next'

import type { ConversationCounts } from '../../api/types'
import { cx } from '../next/cx'
import type { ConversationsSearch } from './search'

type TabKey = ConversationsSearch['assignee_type']

const TABS: { key: TabKey; count: keyof ConversationCounts }[] = [
  { key: 'me', count: 'mine_count' },
  { key: 'unassigned', count: 'unassigned_count' },
  { key: 'all', count: 'all_count' },
]

type Props = {
  active: TabKey
  counts: ConversationCounts | undefined
  onChange: (tab: TabKey) => void
}

export function ChatTypeTabs({ active, counts, onChange }: Props) {
  const { t } = useTranslation()

  return (
    <div className="-mt-1 flex h-10 w-full px-3 py-0">
      <ul
        className="mb-0 flex min-w-[6.25rem] list-none border-x-0 border-t-0 p-0 py-0"
        role="tablist"
      >
        {TABS.map(({ key, count }) => {
          const selected = key === active
          return (
            <li
              key={key}
              className="mx-2 my-0 flex-shrink-0 text-sm first:ml-0 last:mr-0 hover:text-n-slate-12"
            >
              <button
                type="button"
                role="tab"
                aria-selected={selected}
                onClick={() => onChange(key)}
                className={cx(
                  'text-button relative flex cursor-pointer select-none flex-row items-center py-2.5 font-medium after:absolute after:bottom-px after:left-0 after:right-0 after:h-[2px] after:rounded-full after:transition-all after:duration-200',
                  selected
                    ? 'text-n-blue-11 after:bg-n-brand after:opacity-100'
                    : 'text-n-slate-11 after:bg-transparent after:opacity-0',
                )}
              >
                {t(`CHAT_LIST.ASSIGNEE_TYPE_TABS.${key}`)}
                <div
                  className={cx(
                    'my-0 ml-1 flex h-5 min-w-[20px] items-center justify-center rounded-full px-1.5 py-0 text-xs font-medium',
                    selected ? 'bg-n-blue-3 text-n-blue-11' : 'bg-n-alpha-1 text-n-slate-10',
                  )}
                >
                  <span>{counts?.[count] ?? 0}</span>
                </div>
              </button>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
