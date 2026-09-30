import { afterEach, describe, expect, test, vi } from 'vitest'

import { api, ApiError } from './client'

function respond(status: number, body: unknown) {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify(body), { status })))
}

afterEach(() => vi.unstubAllGlobals())

describe('api client', () => {
  test('devolve o JSON de respostas 2xx', async () => {
    respond(200, { id: 1 })
    expect(await api.get('/api/v1/profile')).toEqual({ id: 1 })
  })

  test('envia JSON e cookie da mesma origem', async () => {
    respond(200, {})
    await api.post('/auth/sign_in', { email: 'a@b.c' })
    const [, init] = vi.mocked(fetch).mock.calls[0]
    expect(init).toMatchObject({
      method: 'POST',
      credentials: 'same-origin',
      body: '{"email":"a@b.c"}',
      headers: { 'Content-Type': 'application/json' },
    })
  })

  test.each([
    [{ errors: ['a', 'b'] }, ['a', 'b']],
    [{ error: 'só uma' }, ['só uma']],
    [{ message: 'msg' }, ['msg']],
    [{}, []],
  ])('erro %j vira ApiError com as mensagens', async (body, messages) => {
    respond(401, body)
    const error = await api.get('/x').catch((e: unknown) => e)
    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({ status: 401, messages })
  })
})
