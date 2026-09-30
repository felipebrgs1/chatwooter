import { createMemoryHistory, createRouter } from '@tanstack/react-router'
import { expect, test } from 'vitest'

import { routeTree } from '../routeTree.gen'

// Rota = arquivo: o caminho da URL é exatamente o caminho do arquivo em src/routes.
// Segmentos com "_" no início são layouts sem URL; "$x" é parâmetro; "index" é a raiz da pasta.
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
  const files = Object.keys(import.meta.glob(['./**/*.tsx', '!./**/*.test.tsx', '!./__root.tsx']))
  const router = createRouter({
    routeTree,
    history: createMemoryHistory({ initialEntries: ['/'] }),
  })
  const urls = Object.keys(router.routesByPath).sort()

  expect(files.map(urlFor).sort()).toEqual(urls)
})
