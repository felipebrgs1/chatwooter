import { createFileRoute } from '@tanstack/react-router'

import { EmptyState } from '../../../../components/conversation/empty-state'

export const Route = createFileRoute('/app/_authenticated/_conversations/')({
  component: EmptyState,
})
