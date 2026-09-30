import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/app/_authenticated/')({
  component: ConversationsPlaceholder,
})

function ConversationsPlaceholder() {
  return <section className="flex h-full w-full bg-n-background" />
}
