import type { Profile, ProfileAccount } from '../api/types'

export function accountFixture(overrides: Partial<ProfileAccount> = {}): ProfileAccount {
  return {
    id: 1,
    name: 'Acme',
    status: 'active',
    onboarding_step: null,
    active_at: null,
    role: 'administrator',
    permissions: ['administrator'],
    availability: 'online',
    availability_status: 'online',
    auto_offline: false,
    api_and_webhooks: true,
    ...overrides,
  }
}

export function profileFixture(overrides: Partial<Profile> = {}): Profile {
  return {
    access_token: 'token',
    account_id: 1,
    available_name: 'Ana Souza',
    avatar_url: '',
    confirmed: true,
    display_name: null,
    message_signature: null,
    email: 'ana@example.com',
    id: 10,
    inviter_id: null,
    name: 'Ana Souza',
    provider: 'email',
    pubsub_token: 'pubsub',
    role: 'administrator',
    ui_settings: {},
    uid: 'ana@example.com',
    type: null,
    accounts: [accountFixture(), accountFixture({ id: 2, name: 'Globex', role: 'agent' })],
    ...overrides,
  }
}
