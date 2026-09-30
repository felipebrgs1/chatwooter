import { QueryClient } from '@tanstack/react-query'
import { createMemoryHistory } from '@tanstack/react-router'
import { expect, test } from 'vitest'

import { createAppRouter } from '../router'

// Rota = arquivo: o caminho da URL é exatamente o caminho do arquivo em src/routes.
// Segmentos com "_" no início são layouts sem URL (o arquivo `_x.tsx` do layout não conta como página); "$x" é parâmetro; "index" é a raiz da pasta.
function urlFor(file: string) {
  const segments = file
    .replace('./', '')
    .replace(/\.tsx$/, '')
    .split(/[./]/)
    .filter((s) => !s.startsWith('_'))
  if (segments.at(-1) === 'index') segments.pop()
  return '/' + segments.join('/')
}

test('cada arquivo de rota tem a URL do seu caminho, e vice-versa', () => {
  const files = Object.keys(
    import.meta.glob(['./**/*.tsx', '!./**/*.test.tsx', '!./__root.tsx', '!./**/_*.tsx']),
  )
  const router = createAppRouter(new QueryClient(), createMemoryHistory({ initialEntries: ['/'] }))
  const urls = Object.keys(router.routesByPath).sort()

  expect(files.map(urlFor).sort()).toEqual(urls)
})
