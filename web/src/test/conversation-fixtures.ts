import type { Contact, Conversation, Message } from '../api/types'

export function contactFixture(overrides: Partial<Contact> = {}): Contact {
  return {
    id: 100,
    name: 'Maria Cliente',
    email: 'maria@example.com',
    phone_number: '+5511999990000',
    identifier: null,
    thumbnail: '',
    blocked: false,
    additional_attributes: {},
    custom_attributes: {},
    ...overrides,
  }
}

export function messageFixture(overrides: Partial<Message> = {}): Message {
  return {
    id: 1,
    content: 'Olá, preciso de ajuda',
    inbox_id: 1,
    conversation_id: 1,
    message_type: 0,
    content_type: 'text',
    status: 'sent',
    content_attributes: {},
    created_at: 1_790_000_000,
    private: false,
    source_id: null,
    sender: { id: 100, name: 'Maria Cliente', type: 'contact' },
    ...overrides,
  }
}

export function conversationFixture(overrides: Partial<Conversation> = {}): Conversation {
  const message = messageFixture()
  return {
    id: 1,
    account_id: 1,
    uuid: '00000000-0000-0000-0000-000000000001',
    inbox_id: 1,
    status: 'open',
    priority: null,
    muted: false,
    can_reply: true,
    labels: [],
    snoozed_until: null,
    unread_count: 0,
    additional_attributes: {},
    custom_attributes: {},
    agent_last_seen_at: 0,
    assignee_last_seen_at: 0,
    contact_last_seen_at: 0,
    first_reply_created_at: 0,
    created_at: 1_790_000_000,
    updated_at: 1_790_000_000.5,
    timestamp: 1_790_000_000,
    last_activity_at: 1_790_000_000,
    waiting_since: 0,
    sla_policy_id: null,
    messages: [message],
    last_non_activity_message: message,
    meta: { sender: contactFixture(), channel: 'Channel::Telegram', hmac_verified: null },
    ...overrides,
  }
}
