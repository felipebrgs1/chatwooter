// Port de components/widgets/conversation/contextMenu/menuItem.vue. <button> no lugar do
// div role="button": mesmo papel, com teclado de graça.
import { Avatar, type AvatarStatus } from '../../next/avatar'
import { cx } from '../../next/cx'
import { Icon } from '../../next/icon'

export type MenuOption = {
  label: string
  icon?: string
  /** Etiqueta: cor vem do banco (labels.color). */
  color?: string
  thumbnail?: string
  status?: AvatarStatus | null
}

type Variant = 'default' | 'icon' | 'label' | 'label-assigned' | 'agent'

type Props = {
  option: MenuOption
  variant?: Variant
  disabled?: boolean
  onClick: () => void
}

export function MenuItem({ option, variant = 'default', disabled = false, onClick }: Props) {
  const isLabel = variant === 'label' || variant === 'label-assigned'
  return (
    <button
      type="button"
      disabled={disabled}
      className={cx(
        'group flex w-[12.5rem] min-h-7 min-w-0 cursor-pointer flex-nowrap items-center overflow-hidden rounded-md p-1 text-start text-n-slate-12',
        disabled ? 'cursor-not-allowed opacity-50' : 'hover:bg-n-brand hover:text-white',
      )}
      // a busca de etiquetas não perde o foco (o @mousedown.prevent do Chatwoot)
      onMouseDown={(event) => isLabel && event.preventDefault()}
      onClick={(event) => {
        event.stopPropagation()
        onClick()
      }}
    >
      {variant === 'icon' && option.icon && (
        <Icon name={option.icon} className="size-3.5 flex-shrink-0" />
      )}
      {isLabel && option.color && (
        <span
          className="size-4 flex-shrink-0 rounded-full border border-solid border-n-strong"
          style={{ backgroundColor: option.color }}
        />
      )}
      {variant === 'agent' && (
        <span aria-hidden="true" className="flex-shrink-0">
          <Avatar
            name={option.label}
            src={option.thumbnail}
            status={option.status === 'online' ? option.status : null}
            size={20}
          />
        </span>
      )}
      <p className="mx-2 my-0 min-w-0 flex-1 flex-shrink-0 truncate text-xs">{option.label}</p>
      {variant === 'label-assigned' && (
        <Icon
          name="ph-check"
          className="size-3.5 flex-shrink-0 text-n-brand group-hover:text-white"
        />
      )}
    </button>
  )
}
