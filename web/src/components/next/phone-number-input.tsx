// Port de components-next/phonenumberinput/PhoneNumberInput.vue: país (bandeira + DDI) + número local.
import { getCountryForTimezone } from 'countries-and-timezones'
import parsePhoneNumber from 'libphonenumber-js'
import { useEffect, useId, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { countries } from '../../shared/countries'
import { Button } from './button'
import { cx } from './cx'
import { DropdownMenu } from './dropdown-menu'
import { Input } from './input'

type Props = {
  value: string
  onChange: (value: string) => void
  placeholder?: string
  disabled?: boolean
  showBorder?: boolean
}

// shared/components/PhoneInput/helper.js: sem número, o país vem do fuso do navegador
function countryFromTimezone() {
  const id = getCountryForTimezone(Intl.DateTimeFormat().resolvedOptions().timeZone)?.id ?? ''
  return { code: id, dial: countries.find((c) => c.id === id)?.dial_code ?? '' }
}

function parse(value: string) {
  const number = value ? parsePhoneNumber(value) : undefined
  if (!number) return null
  return {
    code: number.country ?? '',
    dial: `+${number.countryCallingCode}`,
    local: value.replace(`+${number.countryCallingCode}`, ''),
  }
}

// Regras do vuelidate: número numérico com 2+ dígitos (vazio vale) e DDI da lista
const validNumber = (local: string) => local === '' || (/^\d+$/.test(local) && local.length >= 2)
const validDial = (dial: string) => countries.some((c) => c.dial_code === dial)

export function PhoneNumberInput({
  value,
  onChange,
  placeholder = '',
  disabled = false,
  showBorder = true,
}: Props) {
  const { t } = useTranslation()
  const menuId = useId()
  const initial = parse(value)
  const guess = countryFromTimezone()
  const [code, setCode] = useState(initial?.code ?? guess.code)
  const [dial, setDial] = useState(initial?.dial ?? guess.dial)
  const [local, setLocal] = useState(initial?.local ?? '')
  const [dirty, setDirty] = useState(false)
  const [open, setOpen] = useState(false)
  const wrapper = useRef<HTMLDivElement>(null)

  // o valor mudou por fora (outro contato carregado): refaz país, DDI e número
  const [seen, setSeen] = useState(value)
  const [emitted, setEmitted] = useState(value)
  if (value !== seen) {
    setSeen(value)
    if (value !== emitted) {
      const next = parse(value)
      if (next) {
        if (next.code) setCode(next.code)
        setDial(next.dial)
        setLocal(next.local)
      }
    }
  }

  useEffect(() => {
    if (!open) return
    const onClick = (event: MouseEvent) => {
      if (!wrapper.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('click', onClick)
    return () => document.removeEventListener('click', onClick)
  }, [open])

  const hasError = !validNumber(local) || !validDial(dial)
  const error = !dirty
    ? ''
    : !validDial(dial)
      ? t('PHONE_INPUT.DIAL_CODE_ERROR')
      : !validNumber(local)
        ? t('PHONE_INPUT.ERROR')
        : ''
  const active = countries.find((c) => c.id === code)

  function emit(nextDial: string, nextLocal: string) {
    const next = nextLocal ? `${nextDial}${nextLocal}` : ''
    setEmitted(next)
    onChange(next)
  }

  const border = !showBorder
    ? hasError
      ? 'outline-n-ruby-8 hover:outline-n-ruby-9'
      : 'outline-transparent has-[:focus]:outline-n-brand'
    : hasError
      ? 'outline-n-ruby-8 hover:outline-n-ruby-9'
      : 'has-[:focus]:outline-n-brand outline-n-weak hover:outline-n-slate-6'

  return (
    <div>
      <div
        ref={wrapper}
        className={cx(
          'relative flex h-8 items-center rounded-lg bg-n-alpha-black2 outline outline-1 outline-offset-[-1px] transition-all duration-500 ease-in-out',
          border,
          disabled && 'cursor-not-allowed opacity-50',
        )}
      >
        <div className="flex flex-shrink-0 items-center">
          <Button
            label={active?.emoji ?? ''}
            color="slate"
            size="sm"
            icon={active ? 'ph-caret-down' : 'ph-globe'}
            trailingIcon
            disabled={disabled}
            aria-haspopup="listbox"
            aria-expanded={open}
            className="top-1 !h-[1.875rem] !rounded-lg border-0 !px-2 !outline-none outline-0 ltr:ml-px ltr:!rounded-r-none rtl:mr-px rtl:!rounded-l-none"
            onClick={() => setOpen((o) => !o)}
          />
          {active && <span className="text-sm text-n-slate-11 ltr:!pl-1 rtl:!pr-1">{dial}</span>}
        </div>
        <Input
          type="tel"
          value={local}
          placeholder={placeholder}
          disabled={disabled}
          inputClassName="!border-0 !outline-none h-8 !py-0.5 !bg-transparent ltr:!pl-1 rtl:!pr-1"
          className="w-full !flex-row"
          onChange={(event) => {
            const next = event.target.value
            setLocal(next)
            setDirty(true)
            if (validNumber(next) && validDial(dial)) emit(dial, next)
          }}
        />
        <DropdownMenu
          id={menuId}
          open={open}
          items={countries.map((c) => ({ value: c.id, label: c.name, emoji: c.emoji }))}
          selected={code}
          searchPlaceholder={t('PHONE_INPUT.SEARCH_PLACEHOLDER')}
          emptyState={t('DROPDOWN_MENU.EMPTY_STATE')}
          className="top-full z-[100] mt-2 max-h-52 w-48 ltr:left-0 rtl:right-0"
          renderItem={(item) => <span aria-hidden="true">{item.emoji}</span>}
          onSelect={(id) => {
            const country = countries.find((c) => c.id === id)
            if (!country) return
            setCode(country.id)
            setDial(country.dial_code)
            setOpen(false)
            if (validNumber(local) && local) emit(country.dial_code, local)
          }}
        />
      </div>
      {error && (
        <p className="mb-0 mt-1 min-w-0 truncate text-xs text-n-ruby-9 transition-all duration-500 ease-in-out">
          {error}
        </p>
      )}
    </div>
  )
}
