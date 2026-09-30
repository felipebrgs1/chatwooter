// Port de components-next/filter/SaveCustomView.vue: dá nome aos filtros aplicados e salva como pasta.
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { ApiError } from '../../../api/client'
import { createCustomFilter, customFilterKeys } from '../../../api/custom-filters'
import type { CustomFilter, FilterCondition } from '../../../api/types'
import { useAccountId } from '../../../api/use-account-id'
import { showAlert } from '../../toast/alert'
import { Button } from '../button'
import { Input } from '../input'

type Props = {
  query: { payload: FilterCondition[] }
  onClose: () => void
  /** openLastSavedItem: abre a pasta recém-criada. */
  onSaved: (folder: CustomFilter) => void
}

// O botão de salvar fica de fora do clique-fora (#saveFilterTeleportTarget no Chatwoot)
export const SAVE_FILTER_TOGGLE_ID = 'saveFilterToggleButton'

export function SaveCustomView({ query, onClose, onSaved }: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const queryClient = useQueryClient()
  const [name, setName] = useState('')
  const [touched, setTouched] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const invalid = !name.trim()

  useEffect(() => {
    const onPointerDown = (event: MouseEvent) => {
      const target = event.target as Element
      if (ref.current?.contains(target) || target.closest?.(`#${SAVE_FILTER_TOGGLE_ID}`)) return
      onClose()
    }
    document.addEventListener('mousedown', onPointerDown)
    return () => document.removeEventListener('mousedown', onPointerDown)
  }, [onClose])

  const save = useMutation({
    // filter_type 0 (conversation), como o SaveCustomView.vue manda
    mutationFn: () => createCustomFilter(accountId, { name, filter_type: 0, query }),
    onSuccess: async (folder) => {
      showAlert(t('FILTER.CUSTOM_VIEWS.ADD.API_FOLDERS.SUCCESS_MESSAGE'))
      await queryClient.invalidateQueries({ queryKey: customFilterKeys.all(accountId) })
      onClose()
      onSaved(folder)
    },
    onError: (error) => {
      const message = error instanceof ApiError ? error.message : ''
      showAlert(message || t('FILTER.CUSTOM_VIEWS.ADD.API_FOLDERS.ERROR_MESSAGE'))
    },
  })

  return (
    <div
      ref={ref}
      className="z-40 max-w-3xl lg:w-[500px] overflow-visible w-full border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg rounded-xl p-6 grid gap-6"
    >
      <h3 className="text-base font-medium leading-6 text-n-slate-12">
        {t('FILTER.CUSTOM_VIEWS.ADD.TITLE')}
      </h3>
      <form
        className="w-full grid gap-6"
        onSubmit={(event) => {
          event.preventDefault()
          setTouched(true)
          if (!invalid) save.mutate()
        }}
      >
        <Input
          value={name}
          onChange={(e) => setName(e.target.value)}
          onBlur={() => setTouched(true)}
          placeholder={t('FILTER.CUSTOM_VIEWS.ADD.PLACEHOLDER')}
          message={touched && invalid ? t('FILTER.CUSTOM_VIEWS.ADD.ERROR_MESSAGE') : undefined}
          messageType={touched && invalid ? 'error' : 'info'}
        />
        <div className="flex flex-row justify-end w-full gap-2">
          <Button size="sm" variant="faded" color="slate" onClick={onClose}>
            {t('FILTER.CUSTOM_VIEWS.ADD.CANCEL_BUTTON')}
          </Button>
          <Button
            type="submit"
            size="sm"
            variant="solid"
            color="blue"
            disabled={invalid}
            isLoading={save.isPending}
          >
            {t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')}
          </Button>
        </div>
      </form>
    </div>
  )
}
