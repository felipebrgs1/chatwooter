import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'

import { Checkbox } from './checkbox'

test('reflete o estado em aria-checked', () => {
  const { rerender } = render(<Checkbox checked={false} />)
  expect(screen.getByRole('checkbox')).toHaveAttribute('aria-checked', 'false')
  rerender(<Checkbox checked />)
  expect(screen.getByRole('checkbox')).toHaveAttribute('aria-checked', 'true')
})

test('indeterminado vira mixed', () => {
  render(<Checkbox indeterminate />)
  expect(screen.getByRole('checkbox')).toHaveAttribute('aria-checked', 'mixed')
})

test('o pai cuida do clique', async () => {
  const onClick = vi.fn()
  render(<Checkbox onClick={onClick} />)
  await userEvent.click(screen.getByRole('checkbox'))
  expect(onClick).toHaveBeenCalledOnce()
})
