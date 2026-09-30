// Port de components-next/Contacts/EmptyState/ContactEmptyState.vue.
// O botão abre o CreateNewContactDialog, que entra com a criação de contato: por ora só visual.
import { Button } from '../next/button'
import { EmptyStateLayout } from '../next/empty-state-layout'
import { sampleContacts } from './contact-empty-state-content'
import { ContactsCard } from './contacts-card'

type Props = { title: string; subtitle: string; buttonLabel: string; className?: string }

export function ContactEmptyState({ title, subtitle, buttonLabel, className }: Props) {
  return (
    <EmptyStateLayout
      title={title}
      subtitle={subtitle}
      className={className}
      backdrop={
        <div className="grid grid-cols-1 gap-4 overflow-hidden p-px">
          {sampleContacts.map((contact) => (
            <ContactsCard key={contact.id} contact={contact} />
          ))}
        </div>
      }
      actions={<Button label={buttonLabel} icon="ph-plus" />}
    />
  )
}
