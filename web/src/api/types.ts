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

// ---- Conversas (formato de api/v1/conversations/partials/_conversation.json.jbuilder) ----

export type ConversationStatus = 'open' | 'resolved' | 'pending' | 'snoozed'
export type ConversationPriority = 'low' | 'medium' | 'high' | 'urgent' | null
export type AssigneeType = 'me' | 'unassigned' | 'assigned' | 'all'

export interface Contact {
  id: number
  name: string
  email: string | null
  phone_number: string | null
  identifier: string | null
  thumbnail: string
  blocked: boolean
  additional_attributes: Record<string, unknown>
  custom_attributes: Record<string, unknown>
  availability_status?: string
  created_at?: number
  last_activity_at?: number
}

/** _contact_inbox.json.jbuilder (a inbox vem no formato _inbox_slim) */
export interface ContactInbox {
  source_id: string
  inbox: {
    id: number
    avatar_url: string
    channel_id: number
    name: string
    channel_type: string
    provider: string | null
  }
}

/** Contato das listas (/contacts, /contacts/search): _contact.json.jbuilder com contact_inboxes */
export interface ContactListItem extends Contact {
  contact_inboxes?: ContactInbox[]
}

/** _note.json.jbuilder (user no formato _agent) */
export interface ContactNote {
  id: number
  content: string
  user?: Agent
  created_at: number
  updated_at: number
}

export interface ContactsPage {
  meta: { count: number; current_page: number | string; has_more?: boolean }
  payload: ContactListItem[]
}

export interface Agent {
  id: number
  account_id: number
  availability_status: Availability
  auto_offline: boolean
  confirmed: boolean
  email: string
  provider: string
  available_name: string
  name: string
  role: Role
  thumbnail: string
}

export interface Team {
  id: number
  name: string
  description: string | null
  allow_auto_assign: boolean
  icon: string
  icon_color: string
  account_id: number
  is_member: boolean
}

/** api/v1/models/_inbox.json.jbuilder (canais do v1; os campos de widget/e-mail/Twilio não vêm) */
export interface Inbox {
  id: number
  avatar_url: string
  channel_id: number
  name: string
  channel_type: string
  greeting_enabled: boolean
  greeting_message: string | null
  working_hours_enabled: boolean
  enable_email_collect: boolean
  csat_survey_enabled: boolean
  enable_auto_assignment: boolean
  out_of_office_message: string | null
  timezone: string
  allow_messages_after_resolved: boolean
  lock_to_single_conversation: boolean
  sender_name_type: 'friendly' | 'professional'
  business_name: string | null
  phone_number: string | null
  provider: string | null
  /** Só Telegram */
  bot_name?: string | null
}

/** api/v1/accounts/labels/index.json.jbuilder */
export interface Label {
  id: number
  title: string
  description: string | null
  color: string
  show_on_sidebar: boolean
}

/** 0 incoming, 1 outgoing, 2 activity, 3 template */
export type MessageType = 0 | 1 | 2 | 3
export type MessageStatus = 'sent' | 'delivered' | 'read' | 'failed'
export type FileType = 'image' | 'audio' | 'video' | 'file' | 'location' | 'fallback' | 'contact'

export interface Attachment {
  id: number
  message_id: number
  file_type: FileType
  account_id: number
  extension: string | null
  data_url: string
  thumb_url: string
  file_size: number
}

export interface MessageSender {
  id: number
  name: string
  available_name?: string
  avatar_url?: string
  thumbnail?: string
  type: 'user' | 'contact' | 'agent_bot'
  availability_status?: string
}

export interface Message {
  id: number
  content: string | null
  inbox_id: number
  echo_id?: string
  /** display_id da conversa */
  conversation_id: number
  message_type: MessageType
  content_type: string
  status: MessageStatus
  content_attributes: Record<string, unknown>
  /** epoch em segundos */
  created_at: number
  private: boolean
  source_id: string | null
  sender?: MessageSender
  attachments?: Attachment[]
}

export interface Conversation {
  /** display_id: o "#123" visível e o id das rotas */
  id: number
  account_id: number
  uuid: string
  inbox_id: number
  status: ConversationStatus
  priority: ConversationPriority
  muted: boolean
  can_reply: boolean
  labels: string[]
  snoozed_until: string | null
  unread_count: number
  additional_attributes: Record<string, unknown>
  custom_attributes: Record<string, unknown>
  agent_last_seen_at: number
  assignee_last_seen_at: number
  contact_last_seen_at: number
  first_reply_created_at: number
  created_at: number
  updated_at: number
  timestamp: number
  last_activity_at: number
  waiting_since: number
  sla_policy_id: number | null
  /** só a última mensagem (ou vazio) */
  messages: Message[]
  last_non_activity_message: Message | null
  meta: {
    sender: Contact
    channel: string | null
    assignee?: Agent
    assignee_type?: 'User' | 'AgentBot'
    team?: Team
    hmac_verified: boolean | null
  }
}

export interface ConversationCounts {
  mine_count: number
  assigned_count: number
  unassigned_count: number
  all_count: number
}

export interface ConversationList {
  data: { meta: ConversationCounts; payload: Conversation[] }
}

export interface MessagesResponse {
  meta: {
    labels: string[]
    additional_attributes: Record<string, unknown>
    contact: Contact & { type: 'contact' }
    assignee?: MessageSender
    agent_last_seen_at: number | null
    assignee_last_seen_at: number | null
  }
  payload: Message[]
}
