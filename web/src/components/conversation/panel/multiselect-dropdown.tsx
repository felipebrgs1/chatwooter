// Port de shared/components/ui/MultiselectDropdown.vue + MultiselectDropdownItems.vue: escolhe um item
// (agente, time, prioridade) com busca. Clicar no item escolhido o desmarca (quem usa decide).
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Avatar } from '../../next/avatar'
import { Button } from '../../next/button'
import { Icon } from '../../next/icon'

export type MultiselectOption = {
  id: number | string | null
  name: string
  /** Ícone Phosphor (prioridade); sem ícone, mostra o avatar. */
  icon?: string
  thumbnail?: string
  availability_status?: string
}

type Props = {
  options: MultiselectOption[]
  selectedItem: MultiselectOption | null | undefined
  onSelect: (option: MultiselectOption) => void
  multiselectorTitle: string
  multiselectorPlaceholder: string
  noSearchResult: string
  inputPlaceholder: string
  hasThumbnail?: boolean
}

const avatarStatus = (status?: string) =>
  // hide-offline-status
  status === 'online' || status === 'busy' ? status : null

export function MultiselectDropdown({
  options,
  selectedItem,
  onSelect,
  multiselectorTitle,
  multiselectorPlaceholder,
  noSearchResult,
  inputPlaceholder,
  hasThumbnail = true,
}: Props) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const ref = useRef<HTMLDivElement>(null)
  const hasValue = !!selectedItem?.id
  const filtered = options.filter((o) =>
    (o.name || '').toLowerCase().includes(search.toLowerCase()),
  )

  useEffect(() => {
    if (!open) return
    const onPointerDown = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onPointerDown)
    return () => document.removeEventListener('mousedown', onPointerDown)
  }, [open])

  const close = () => {
    setOpen(false)
    setSearch('')
  }

  return (
    <div ref={ref} className="relative w-full mb-2" onKeyUp={(e) => e.key === 'Escape' && close()}>
      <Button
        color="slate"
        variant="outline"
        trailingIcon
        icon={open ? 'ph-caret-up' : 'ph-caret-down'}
        className="w-full !px-2"
        // sem nome acessível no original: o título do seletor diz o que o botão escolhe
        aria-label={multiselectorTitle}
        aria-expanded={open}
        onClick={() => (open ? close() : setOpen(true))}
      >
        <div className="flex items-center justify-between w-full min-w-0">
          <h4
            className="items-center overflow-hidden text-sm leading-tight whitespace-nowrap text-ellipsis text-n-slate-12"
            title={hasValue ? selectedItem?.name : undefined}
          >
            {hasValue ? selectedItem?.name : multiselectorPlaceholder}
          </h4>
        </div>
        {hasValue && selectedItem?.icon ? (
          <Icon name={selectedItem.icon} className="size-5 text-n-slate-11" />
        ) : (
          hasValue &&
          hasThumbnail && (
            <Avatar
              src={selectedItem?.thumbnail}
              name={selectedItem?.name}
              status={avatarStatus(selectedItem?.availability_status) as never}
              size={24}
            />
          )
        )}
      </Button>
      {open && (
        <div className="box-border top-[2.625rem] w-full border rounded-lg bg-n-alpha-3 backdrop-blur-[100px] absolute shadow-lg border-n-strong dark:border-n-strong p-2 z-[9999]">
          <div className="flex items-center justify-between mb-1">
            <h4 className="m-0 overflow-hidden text-sm text-n-slate-11 whitespace-nowrap text-ellipsis">
              {multiselectorTitle}
            </h4>
            <Button
              variant="ghost"
              color="slate"
              size="xs"
              icon="ph-x"
              aria-label={t('GENERAL.CLOSE')}
              onClick={close}
            />
          </div>
          <div className="w-full flex flex-col max-h-[12.5rem]">
            <div className="flex-auto flex-grow-0 flex-shrink-0 mb-2 max-h-8">
              <input
                autoFocus
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={inputPlaceholder}
                className="m-0 w-full border border-solid border-transparent h-8 text-sm text-n-slate-12 rounded-md focus:border-n-brand bg-n-background px-2"
              />
            </div>
            <div className="flex items-start justify-start flex-auto overflow-auto mt-2">
              <div className="w-full max-h-[10rem]">
                <ul className="list-none m-0 p-0 flex flex-col gap-1">
                  {filtered.map((option) => {
                    const active = selectedItem?.id === option.id && hasValue
                    return (
                      <li key={String(option.id)}>
                        <Button
                          color="slate"
                          variant={active ? 'faded' : 'ghost'}
                          trailingIcon
                          icon={active ? 'ph-check' : undefined}
                          className="w-full !px-2.5"
                          onClick={() => {
                            onSelect(option)
                            close()
                          }}
                        >
                          <div className="flex items-center justify-between w-full min-w-0 gap-2">
                            <span
                              className="my-0 overflow-hidden text-sm leading-4 whitespace-nowrap text-ellipsis"
                              title={option.name}
                            >
                              {option.name}
                            </span>
                          </div>
                          {option.icon ? (
                            <Icon name={option.icon} className="size-5 text-n-slate-11" />
                          ) : (
                            hasThumbnail && (
                              <Avatar
                                src={option.thumbnail}
                                name={option.name}
                                status={avatarStatus(option.availability_status) as never}
                                size={24}
                              />
                            )
                          )}
                        </Button>
                      </li>
                    )
                  })}
                </ul>
                {filtered.length === 0 && search !== '' && (
                  <h4 className="w-full justify-center items-center flex text-n-slate-10 py-2 px-2.5 overflow-hidden whitespace-nowrap text-ellipsis text-sm">
                    {noSearchResult}
                  </h4>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
