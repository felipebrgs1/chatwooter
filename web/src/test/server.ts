import { setupServer } from 'msw/node'

// API falsa dos testes de tela: cada teste registra seus handlers com server.use(...).
export const server = setupServer()
