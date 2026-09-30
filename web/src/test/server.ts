import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'

// API falsa dos testes de tela: cada teste registra seus handlers com server.use(...).
// Padrões: o que a casca do app sempre busca (times, inboxes, etiquetas, agentes e pastas) começa vazio.
export const server = setupServer(
  http.get('/api/v1/accounts/:id/teams', () => HttpResponse.json([])),
  http.get('/api/v1/accounts/:id/labels', () => HttpResponse.json({ payload: [] })),
  http.get('/api/v1/accounts/:id/inboxes', () => HttpResponse.json({ payload: [] })),
  http.get('/api/v1/accounts/:id/agents', () => HttpResponse.json([])),
  http.get('/api/v1/accounts/:id/custom_filters', () => HttpResponse.json([])),
)
