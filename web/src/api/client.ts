// Cliente HTTP do dashboard: a sessão vai no cookie HttpOnly (mesma origem), nunca em JS.
export class ApiError extends Error {
  readonly status: number
  readonly messages: string[]

  constructor(status: number, messages: string[]) {
    super(messages[0] ?? `HTTP ${status}`)
    this.name = 'ApiError'
    this.status = status
    this.messages = messages
  }
}

// O Chatwoot responde erros em {errors: [...]}, {error: "..."} ou {message: "..."}.
function messagesFrom(body: unknown): string[] {
  if (typeof body !== 'object' || body === null) return []
  const { errors, error, message } = body as Record<string, unknown>
  if (Array.isArray(errors)) return errors.map(String)
  if (typeof error === 'string') return [error]
  if (typeof message === 'string') return [message]
  return []
}

export async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const response = await fetch(path, {
    method,
    credentials: 'same-origin',
    headers: body === undefined ? undefined : { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const text = await response.text()
  const json: unknown = text ? JSON.parse(text) : null
  if (!response.ok) throw new ApiError(response.status, messagesFrom(json))
  return json as T
}

export const api = {
  get: <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body?: unknown) => request<T>('POST', path, body),
  put: <T>(path: string, body?: unknown) => request<T>('PUT', path, body),
  delete: <T>(path: string) => request<T>('DELETE', path),
}
