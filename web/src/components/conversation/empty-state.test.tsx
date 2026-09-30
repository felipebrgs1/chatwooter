import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'

import { EmptyState } from './empty-state'
import { renderConversation } from './test-utils'

test('pede para escolher uma conversa na lista', async () => {
  await renderConversation(<EmptyState />)
  expect(screen.getByText('Please select a conversation from left pane')).toBeInTheDocument()
})
