import { render, screen } from '@testing-library/react'
import { expect, test } from 'vitest'

import { FormattedContent } from './formatted-content'

function html(content: string) {
  const { container } = render(<FormattedContent content={content} />)
  return container
}

test('texto simples vira parágrafo', () => {
  html('Olá mundo')
  expect(screen.getByText('Olá mundo')).toBeInTheDocument()
})

test('negrito, itálico e código inline', () => {
  const c = html('**forte** e *itálico* e `código`')
  expect(c.querySelector('strong')).toHaveTextContent('forte')
  expect(c.querySelector('em')).toHaveTextContent('itálico')
  expect(c.querySelector('code')).toHaveTextContent('código')
})

test('URLs viram links que abrem em nova aba sem opener', () => {
  html('veja https://example.com/a?b=1 agora')
  const link = screen.getByRole('link', { name: 'https://example.com/a?b=1' })
  expect(link).toHaveAttribute('href', 'https://example.com/a?b=1')
  expect(link).toHaveAttribute('target', '_blank')
  expect(link).toHaveAttribute('rel', expect.stringContaining('noopener'))
})

test('quebras de linha viram <br>', () => {
  const c = html('linha 1\nlinha 2')
  expect(c.querySelectorAll('br')).toHaveLength(1)
})

test('HTML vindo do cliente nunca é interpretado', () => {
  const c = html('<img src=x onerror="alert(1)"><script>alert(2)</script>')
  expect(c.querySelector('img')).toBeNull()
  expect(c.querySelector('script')).toBeNull()
  expect(c).toHaveTextContent('<img src=x onerror="alert(1)">')
})

test('links javascript: não viram link', () => {
  html('[clique](javascript:alert(1)) e javascript:alert(1)')
  expect(screen.queryByRole('link')).toBeNull()
})
