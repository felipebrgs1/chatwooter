import { render } from '@testing-library/react'
import { expect, test } from 'vitest'

import { Icon } from './icon'

test('renderiza o ícone pelo nome ph-*', () => {
  const { container } = render(<Icon name="ph-check" className="size-4" />)
  const svg = container.querySelector('svg')
  expect(svg).toHaveClass('size-4')
  expect(svg).toHaveAttribute('aria-hidden', 'true')
})

test('o sufixo do nome escolhe o peso', () => {
  const regular = render(<Icon name="ph-check" />).container.innerHTML
  const fill = render(<Icon name="ph-check-fill" />).container.innerHTML
  expect(fill).not.toBe(regular)
})

test('nome desconhecido falha em vez de sumir', () => {
  expect(() => render(<Icon name="ph-inexistente" />)).toThrow(/ph-inexistente/)
})
