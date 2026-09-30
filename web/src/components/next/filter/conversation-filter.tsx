// Port de components-next/filter/ConversationFilter.vue: o modal de filtros avançados (e de editar pasta).
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '../button'
import { Input } from '../input'
import { ConditionRow } from './condition-row'
import { DEFAULT_FILTER, validateSingleFilter, type FilterRow } from './filter-query'
import { useConversationFilterTypes } from './use-conversation-filter-types'

type Props = {
  initialFilters: FilterRow[]
  isFolderView?: boolean
  folderName?: string
  onApply: (filters: FilterRow[]) => void
  onUpdateFolder?: (filters: FilterRow[], folderName: string) => void
  onClose: () => void
}

type KeyedRow = { key: number; row: FilterRow }

// chave estável de cada linha (o `filter.id` do Vue): as linhas mudam de posição ao remover
let nextKey = 0
const keyed = (row: FilterRow): KeyedRow => ({ key: nextKey++, row })

// O botão que abre o modal fica de fora do clique-fora (senão ele fecharia e reabriria)
export const FILTER_TOGGLE_ID = 'toggleConversationFilterButton'

export function ConversationFilter({
  initialFilters,
  isFolderView = false,
  folderName = '',
  onApply,
  onUpdateFolder,
  onClose,
}: Props) {
  const { t } = useTranslation()
  const { filterTypes, attributeOptions } = useConversationFilterTypes()
  const [rows, setRows] = useState<KeyedRow[]>(() =>
    (initialFilters.length ? initialFilters : [DEFAULT_FILTER]).map(keyed),
  )
  const [folderNameLocal, setFolderNameLocal] = useState(folderName)
  // linhas que já tentaram enviar: o erro aparece até a linha mudar
  const [withErrors, setWithErrors] = useState<Set<number>>(new Set())
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const onPointerDown = (event: MouseEvent) => {
      const target = event.target as Element
      if (ref.current?.contains(target) || target.closest?.(`#${FILTER_TOGGLE_ID}`)) return
      onClose()
    }
    document.addEventListener('mousedown', onPointerDown)
    return () => document.removeEventListener('mousedown', onPointerDown)
  }, [onClose])

  const update = (key: number, change: (row: FilterRow) => FilterRow) => {
    setRows((current) => current.map((r) => (r.key === key ? { ...r, row: change(r.row) } : r)))
    setWithErrors((current) => {
      const next = new Set(current)
      next.delete(key)
      return next
    })
  }
  const reset = () => setRows([keyed({ ...DEFAULT_FILTER })])
  const remove = (key: number) =>
    rows.length === 1 ? reset() : setRows((current) => current.filter((r) => r.key !== key))

  const valid = () => {
    const invalid = rows.filter((r) => validateSingleFilter(r.row)).map((r) => r.key)
    setWithErrors(new Set(invalid))
    return invalid.length === 0
  }
  const filters = () => rows.map((r) => r.row)

  return (
    <div
      ref={ref}
      className="z-40 w-[min(34rem,calc(100vw-2rem))] lg:w-[750px] overflow-visible border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg rounded-xl p-6 grid gap-6"
    >
      <h3 className="text-base font-medium leading-6 text-n-slate-12">
        {isFolderView ? t('FILTER.EDIT_CUSTOM_FILTER') : t('FILTER.TITLE')}
      </h3>
      {isFolderView && (
        <div>
          <div className="border-b border-n-weak pb-6">
            <Input
              value={folderNameLocal}
              onChange={(e) => setFolderNameLocal(e.target.value)}
              label={t('FILTER.FOLDER_LABEL')}
              placeholder={t('FILTER.INPUT_PLACEHOLDER')}
            />
          </div>
        </div>
      )}
      <ul data-filter-conditions className="grid gap-4 list-none min-w-0">
        {rows.map(({ key, row }, index) => {
          const previous = rows[index - 1]
          return (
            <ConditionRow
              key={key}
              row={row}
              onChange={(next) => update(key, () => next)}
              onRemove={() => remove(key)}
              filterTypes={filterTypes}
              attributeOptions={attributeOptions}
              queryOperator={previous?.row.query_operator}
              onQueryOperatorChange={
                previous
                  ? (query_operator) => update(previous.key, (r) => ({ ...r, query_operator }))
                  : undefined
              }
              showErrors={withErrors.has(key)}
            />
          )
        })}
      </ul>
      <div className="flex gap-2 justify-between">
        <Button
          size="sm"
          variant="ghost"
          color="blue"
          onClick={() => setRows((r) => [...r, keyed({ ...DEFAULT_FILTER })])}
        >
          {t('FILTER.ADD_NEW_FILTER')}
        </Button>
        <div className="flex gap-2">
          <Button size="sm" variant="faded" color="slate" onClick={reset}>
            {t('FILTER.CLEAR_BUTTON_LABEL')}
          </Button>
          {isFolderView ? (
            <Button
              size="sm"
              variant="solid"
              color="blue"
              disabled={!folderNameLocal}
              onClick={() => valid() && onUpdateFolder?.(filters(), folderNameLocal)}
            >
              {t('FILTER.UPDATE_BUTTON_LABEL')}
            </Button>
          ) : (
            <Button
              size="sm"
              variant="solid"
              color="blue"
              onClick={() => valid() && onApply(filters())}
            >
              {t('FILTER.SUBMIT_BUTTON_LABEL')}
            </Button>
          )}
        </div>
      </div>
    </div>
  )
}
