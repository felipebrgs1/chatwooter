// Port de components-next/selectmenu/SelectMenu.vue (sub-menu que abre à direita do botão).
import { Button } from '../next/button'
import { DropdownContainer } from '../next/dropdown-container'
import { cx } from '../next/cx'

export type SelectOption<T extends string> = { value: T; label: string }

type Props<T extends string> = {
  /** Nome acessível da lista de opções. */
  label: string
  value: T
  options: SelectOption<T>[]
  onChange: (value: T) => void
}

export function SelectMenu<T extends string>({ label, value, options, onChange }: Props<T>) {
  const current = options.find((o) => o.value === value)?.label ?? ''

  return (
    <DropdownContainer
      trigger={({ toggle, triggerProps }) => (
        <Button
          {...triggerProps}
          icon="ph-caret-down"
          trailingIcon
          size="sm"
          color="slate"
          variant="faded"
          label={current}
          aria-haspopup="listbox"
          onClick={toggle}
          className="!w-fit max-w-40"
        />
      )}
    >
      {({ close }) => (
        <ul
          role="listbox"
          aria-label={label}
          className="absolute left-full top-0 z-40 ml-1 flex max-w-64 select-none flex-col gap-1 rounded-lg border border-n-weak bg-n-alpha-3 p-1 shadow-lg backdrop-blur-[100px] dark:border-n-strong/50"
        >
          {options.map((option) => (
            <li key={option.value} role="presentation">
              <Button
                role="option"
                aria-selected={option.value === value}
                label={option.label}
                icon={option.value === value ? 'ph-check' : undefined}
                size="sm"
                variant="ghost"
                color="slate"
                trailingIcon
                onClick={() => {
                  onChange(option.value)
                  close()
                }}
                className={cx(
                  '!h-7 !justify-end !px-2.5',
                  option.value === value && '!bg-n-alpha-2',
                )}
              />
            </li>
          ))}
        </ul>
      )}
    </DropdownContainer>
  )
}
