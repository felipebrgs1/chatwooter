import {
  AddressBook,
  At,
  Broadcast,
  Briefcase,
  Buildings,
  CaretDoubleDown,
  CaretUp,
  ChatCircle,
  ClockCountdown,
  Folder,
  Info,
  Lightning,
  List,
  NotePencil,
  Power,
  Tag,
  UserCircle,
  UserGear,
  Users,
  UserSquare,
  CaretDown,
  CaretRight,
  Check,
  MagnifyingGlass,
  TelegramLogo,
  Tray,
  User,
  WhatsappLogo,
  Checks,
  Clock,
  LockKey,
  Warning,
  ArrowClockwise,
  DownloadSimple,
  File,
  ImageBroken,
  ArrowBendUpLeft,
  ArrowsDownUp,
  CaretLeft,
  CellSignalFull,
  CellSignalHigh,
  CellSignalLow,
  CellSignalMedium,
  Headphones,
  Image,
  Link,
  LockSimple,
  MapPin,
  VideoCamera,
  type Icon as PhosphorIcon,
} from '@phosphor-icons/react'

// Só os ícones que os componentes `next/*` usam; mantém o bundle pequeno. Ícone novo entra aqui.
const icons: Record<string, PhosphorIcon> = {
  checks: Checks,
  clock: Clock,
  'lock-key': LockKey,
  warning: Warning,
  'arrow-clockwise': ArrowClockwise,
  'download-simple': DownloadSimple,
  file: File,
  'image-broken': ImageBroken,

  'address-book': AddressBook,
  at: At,
  broadcast: Broadcast,
  briefcase: Briefcase,
  buildings: Buildings,
  'caret-double-down': CaretDoubleDown,
  'caret-up': CaretUp,
  'chat-circle': ChatCircle,
  'clock-countdown': ClockCountdown,
  folder: Folder,
  info: Info,
  lightning: Lightning,
  list: List,
  'note-pencil': NotePencil,
  power: Power,
  tag: Tag,
  'user-circle': UserCircle,
  'user-gear': UserGear,
  users: Users,
  'user-square': UserSquare,
  'caret-down': CaretDown,
  'caret-right': CaretRight,
  check: Check,
  'magnifying-glass': MagnifyingGlass,
  'telegram-logo': TelegramLogo,
  tray: Tray,
  user: User,
  'whatsapp-logo': WhatsappLogo,
  'video-camera': VideoCamera,
  'map-pin': MapPin,
  'lock-simple': LockSimple,
  link: Link,
  image: Image,
  headphones: Headphones,
  'cell-signal-medium': CellSignalMedium,
  'cell-signal-low': CellSignalLow,
  'cell-signal-high': CellSignalHigh,
  'cell-signal-full': CellSignalFull,
  'caret-left': CaretLeft,
  'arrows-down-up': ArrowsDownUp,
  'arrow-bend-up-left': ArrowBendUpLeft,
}

const weights = ['thin', 'light', 'bold', 'fill', 'duotone'] as const
type Weight = (typeof weights)[number]

function resolve(name: string): { Component: PhosphorIcon; weight: Weight | 'regular' } {
  const base = name.replace(/^ph-/, '')
  const direct = icons[base]
  if (direct) return { Component: direct, weight: 'regular' }
  const weight = weights.find((w) => base.endsWith(`-${w}`))
  const stripped = weight ? base.slice(0, -(weight.length + 1)) : base
  const Component = icons[stripped]
  if (!Component || !weight) throw new Error(`Ícone desconhecido: ${name}`)
  return { Component, weight }
}

type Props = {
  /** Nome no estilo das classes Phosphor do app antigo: `ph-check`, `ph-check-fill`. */
  name: string
  className?: string
}

export function Icon({ name, className }: Props) {
  const { Component, weight } = resolve(name)
  return <Component className={className} weight={weight} aria-hidden="true" />
}
