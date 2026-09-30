import { http, HttpResponse } from 'msw'

import type { Profile } from '../api/types'
import { profileFixture } from './fixtures'
import { server } from './server'

// Visitante: o perfil responde 401, como o servidor sem sessão.
export function asGuest() {
  server.use(
    http.get('/api/v1/profile', () =>
      HttpResponse.json(
        { errors: ['You need to sign in or sign up before continuing.'] },
        { status: 401 },
      ),
    ),
  )
}

export function asSignedIn(profile: Profile = profileFixture()) {
  server.use(http.get('/api/v1/profile', () => HttpResponse.json(profile)))
}
