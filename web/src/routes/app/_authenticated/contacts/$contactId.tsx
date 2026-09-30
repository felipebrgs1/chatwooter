import { createFileRoute, Link, useRouter } from '@tanstack/react-router'

import { ContactManageView } from '../../../../components/contacts/contact-manage-view'

// /app/contacts/:contactId (no Chatwoot: /app/accounts/:id/contacts/:contactId)
export const Route = createFileRoute('/app/_authenticated/contacts/$contactId')({
  component: ContactPage,
})

function ContactPage() {
  const { contactId } = Route.useParams()
  const router = useRouter()
  const navigate = Route.useNavigate()

  // goToContactsList: volta pelo histórico (mantém página e busca da lista); sem histórico, abre a lista
  const goToContactsList = () => {
    if (window.history.length > 1) router.history.back()
    else void navigate({ to: '/app/contacts' })
  }

  return (
    <ContactManageView
      key={contactId}
      contactId={Number(contactId)}
      onGoToContactsList={goToContactsList}
      renderConversationLink={(conversation, { className, children }) => (
        <Link
          to="/app/conversations/$conversationId"
          params={{ conversationId: String(conversation.id) }}
          className={className}
        >
          {children}
        </Link>
      )}
    />
  )
}
