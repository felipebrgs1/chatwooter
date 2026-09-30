// Port de components-next/filter/ConditionRow.vue: uma condição (AND/OR, atributo, operador e valor).
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '../button'
import { cx } from '../cx'
import { Input } from '../input'
import { FilterSelect } from './filter-select'
import {
  inputTypeFor,
  validateSingleFilter,
  type FilterOption,
  type FilterRow,
  type FilterValue,
} from './filter-query'
import { MultiSelect } from './multi-select'
import { SingleSelect } from './single-select'
import type { FilterType, SelectOption, ValueOption } from './use-conversation-filter-types'

type Props = {
  row: FilterRow
  onChange: (row: FilterRow) => void
  onRemove: () => void
  filterTypes: FilterType[]
  attributeOptions: SelectOption[]
  /** O AND/OR mostrado na linha é o da condição anterior (é ele que liga as duas). */
  queryOperator?: FilterRow['query_operator']
  onQueryOperatorChange?: (value: FilterRow['query_operator']) => void
  showErrors: boolean
}

// o valor tem de combinar com o tipo do campo: lista, opção única ou texto
function emptyValueFor(inputType: string): FilterValue {
  if (inputType === 'multiSelect') return []
  if (['searchSelect', 'asyncSearchSelect', 'booleanSelect'].includes(inputType)) return {}
  return ''
}

export function ConditionRow({
  row,
  onChange,
  onRemove,
  filterTypes,
  attributeOptions,
  queryOperator,
  onQueryOperatorChange,
  showErrors,
}: Props) {
  const { t } = useTranslation()
  const current = filterTypes.find((ft) => ft.attributeKey === row.attribute_key)
  const operator =
    current?.filterOperators.find((op) => op.value === row.filter_operator) ??
    current?.filterOperators[0]
  const inputType = inputTypeFor(row.attribute_key, operator?.value ?? row.filter_operator)
  const error = validateSingleFilter(row)

  // busca assíncrona (contato): debounce de 300 ms e só a resposta da última busca vale
  const [asyncOptions, setAsyncOptions] = useState<ValueOption[]>([])
  const [isSearching, setIsSearching] = useState(false)
  const lastQuery = useRef('')
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined)
  useEffect(() => () => clearTimeout(timer.current), [])
  const onAsyncSearch = (query: string) => {
    lastQuery.current = query
    const hasQuery = !!query.trim()
    if (!hasQuery) setAsyncOptions([])
    setIsSearching(hasQuery)
    clearTimeout(timer.current)
    timer.current = setTimeout(async () => {
      let results: ValueOption[] = []
      try {
        results = (await current?.searchOptions?.(query)) ?? []
      } catch {
        results = []
      }
      if (query !== lastQuery.current) return
      setAsyncOptions(results)
      setIsSearching(false)
    }, 300)
  }

  const changeAttribute = (attributeKey: string) => {
    const next = filterTypes.find((ft) => ft.attributeKey === attributeKey)
    const nextOperator =
      next?.filterOperators.find((op) => op.value === row.filter_operator) ??
      next?.filterOperators[0]
    const operatorValue = nextOperator?.value ?? row.filter_operator
    setAsyncOptions([])
    onChange({
      ...row,
      attribute_key: attributeKey,
      filter_operator: operatorValue,
      values: emptyValueFor(inputTypeFor(attributeKey, operatorValue)),
    })
  }

  const setValues = (values: FilterValue) => onChange({ ...row, values })
  const queryOptions = [
    // i-lucide-ampersands e i-woot-logic-or não têm par no Phosphor; o gatilho já esconde o ícone (hide-icon)
    { value: 'and', label: t('FILTER.QUERY_DROPDOWN_LABELS.AND') },
    { value: 'or', label: t('FILTER.QUERY_DROPDOWN_LABELS.OR') },
  ]
  const inputFieldType = inputType === 'date' ? 'date' : inputType === 'number' ? 'number' : 'text'

  return (
    <li className="list-none">
      <div
        className={cx(
          'flex flex-wrap gap-2 rounded-md',
          showErrors && error && 'animate-wiggle',
          'items-center',
        )}
      >
        {onQueryOperatorChange && (
          <FilterSelect
            value={queryOperator ?? 'and'}
            options={queryOptions}
            onChange={(value) => onQueryOperatorChange(value as FilterRow['query_operator'])}
            variant="faded"
            hideIcon
            className="text-sm shrink-0"
          />
        )}
        <FilterSelect
          value={row.attribute_key}
          options={attributeOptions}
          onChange={changeAttribute}
          variant="faded"
          className="shrink-0"
        />
        <FilterSelect
          value={operator?.value ?? row.filter_operator}
          options={current?.filterOperators ?? []}
          onChange={(filter_operator) => onChange({ ...row, filter_operator })}
          variant="ghost"
          className="shrink-0"
        />
        <div className={operator?.hasInput ? 'flex items-start gap-2 min-w-0' : 'contents'}>
          {operator?.hasInput &&
            (inputType === 'multiSelect' ? (
              <MultiSelect
                value={Array.isArray(row.values) ? row.values : []}
                options={current?.options ?? []}
                onChange={setValues}
                dropdownMaxHeight="max-h-72"
              />
            ) : inputType === 'searchSelect' || inputType === 'asyncSearchSelect' ? (
              <SingleSelect
                value={
                  row.values && typeof row.values === 'object' ? (row.values as FilterOption) : null
                }
                options={
                  inputType === 'asyncSearchSelect' ? asyncOptions : (current?.options ?? [])
                }
                onChange={(value) => setValues(value ?? {})}
                asyncSearch={inputType === 'asyncSearchSelect'}
                isSearching={isSearching}
                onSearch={inputType === 'asyncSearchSelect' ? onAsyncSearch : undefined}
                searchPlaceholder={current?.searchPlaceholder}
                dropdownMaxHeight="max-h-64"
              />
            ) : (
              <Input
                type={inputFieldType}
                value={typeof row.values === 'string' ? row.values : ''}
                onChange={(e) => setValues(e.target.value)}
                inputClassName="h-8 py-1.5 outline-offset-0"
                placeholder={t('FILTER.INPUT_PLACEHOLDER')}
              />
            ))}
          <Button
            size="sm"
            color="slate"
            variant="solid"
            icon="ph-trash"
            // o ConditionRow.vue não dá nome ao botão só de ícone; "Delete" (do mesmo formulário de automação) dá
            aria-label={t('AUTOMATION.FORM.DELETE')}
            className="flex-shrink-0"
            onClick={(e) => {
              e.stopPropagation()
              onRemove()
            }}
          />
        </div>
      </div>
      {showErrors && error && (
        <span className="text-sm text-n-ruby-11">{t(`FILTER.ERRORS.${error}`)}</span>
      )}
    </li>
  )
}
