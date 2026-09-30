// Formato do JSON do Chatwoot (app/views/api/v1/models/_user.json.jbuilder), servido por GET /api/v1/profile.
export type Availability = 'online' | 'offline' | 'busy'
export type Role = 'agent' | 'administrator'

export interface ProfileAccount {
  id: number
  name: string
  status: 'active' | 'suspended'
  onboarding_step: string | null
  active_at: string | null
  role: Role
  permissions: string[]
  availability: Availability
  availability_status: Availability
  auto_offline: boolean
  api_and_webhooks: boolean
}

export interface Profile {
  access_token: string
  account_id: number | null
  available_name: string
  avatar_url: string
  confirmed: boolean
  display_name: string | null
  message_signature: string | null
  email: string
  id: number
  inviter_id: number | null
  name: string
  provider: string
  pubsub_token: string
  custom_attributes?: Record<string, unknown>
  role: Role | null
  ui_settings: Record<string, unknown>
  uid: string
  type: string | null
  accounts: ProfileAccount[]
}

export interface Account {
  id: number
  name: string
  locale: string
  domain: string | null
  support_email: string | null
  status: 'active' | 'suspended'
  features: string[]
  settings: Record<string, unknown>
  created_at: string
  custom_attributes?: Record<string, unknown>
}
