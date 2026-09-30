import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterAll, afterEach, beforeAll } from 'vitest'

import { server } from './server'

// O fetch do Node exige URL absoluta; no navegador o app usa caminhos relativos.
const nativeFetch = globalThis.fetch
globalThis.fetch = ((input: RequestInfo | URL, init?: RequestInit) =>
  nativeFetch(
    typeof input === 'string' && input.startsWith('/') ? `http://localhost${input}` : input,
    init,
  )) as typeof fetch

// jsdom não tem matchMedia: desktop por padrão (nenhuma media query de largura máxima casa)
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: (query: string) => ({
    matches: false,
    media: query,
    addEventListener: () => {},
    removeEventListener: () => {},
  }),
})

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => {
  cleanup()
  server.resetHandlers()
})
afterAll(() => server.close())
