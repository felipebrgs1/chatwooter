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
  /** Lado em que o sub-menu abre (subMenuPosition): à esquerda no layout expandido. */
  position?: 'right' | 'left'
}

export function SelectMenu<T extends string>({
  label,
  value,
  options,
  onChange,
  position = 'right',
}: Props<T>) {
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
          className={cx(
            'absolute top-0 z-40 flex max-w-64 select-none flex-col gap-1 rounded-lg border border-n-weak bg-n-alpha-3 p-1 shadow-lg backdrop-blur-[100px] dark:border-n-strong/50',
            position === 'right' ? 'left-full ml-1' : 'right-full mr-1',
          )}
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
