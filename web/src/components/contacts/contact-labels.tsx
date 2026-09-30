// Port de components-next/Contacts/ContactLabels/ContactLabels.vue: etiquetas do contato (as da conta, na ordem
// da conta) + "tag" para adicionar/remover. Clicar numa já escolhida remove (toggle).
import { useState } from 'react'

import type { Label } from '../../api/types'
import { AddLabel } from '../next/add-label'
import { LabelItem } from '../next/label-item'

type Props = {
  /** Títulos das etiquetas do contato. */
  labels: string[]
  accountLabels: Label[]
  onChange: (titles: string[]) => void
}

export function ContactLabels({ labels, accountLabels, onChange }: Props) {
  // hover controlado em JS (como o original) para o botão de remover não piscar no fim da linha
  const [hovered, setHovered] = useState<number | null>(null)
  const saved = accountLabels.filter(({ title }) => labels.includes(title))

  function toggle(id: number) {
    const label = accountLabels.find((l) => l.id === id)
    if (!label) return
    const current = saved.map((l) => l.title)
    onChange(
      current.includes(label.title)
        ? current.filter((title) => title !== label.title)
        : [...current, label.title],
    )
  }

  return (
    <div className="flex flex-wrap items-center gap-2" onMouseLeave={() => setHovered(null)}>
      {saved.map((label) => (
        <LabelItem
          key={label.id}
          label={label}
          isHovered={hovered === label.id}
          onHover={setHovered}
          onRemove={(l) => toggle(l.id)}
        />
      ))}
      <AddLabel
        items={accountLabels.map((l) => ({ value: l.id, label: l.title, color: l.color }))}
        selected={saved.map((l) => l.id)}
        onSelect={toggle}
      />
    </div>
  )
}
