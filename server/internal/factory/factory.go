// Package factory monta dados de teste reais no Postgres (equivale ao ExMachina do app Elixir).
// Cada construtor recebe mutadores opcionais que alteram os defaults antes do INSERT.
package factory

import (
	"context"
	"fmt"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Account struct {
	ID   int32
	Name string
}

type User struct {
	ID    int32
	Name  string
	Email string
	Role  int32 // 0 agent, 1 administrator
}

type Inbox struct {
	ID        int32
	AccountID int32
	Name      string
	BotToken  string
}

type Contact struct {
	ID        int32
	AccountID int32
	Name      string
	Email     string
}

type Conversation struct {
	ID        int32
	AccountID int32
	InboxID   int32
	ContactID int32
	DisplayID int32
}

type Message struct {
	ID             int32
	ConversationID int32
	AccountID      int32
	InboxID        int32
	Content        string
	Incoming       bool
}

type Factory struct {
	t    testing.TB
	pool *pgxpool.Pool
	seq  int
}

func New(t testing.TB, pool *pgxpool.Pool) *Factory {
	t.Helper()
	return &Factory{t: t, pool: pool}
}

func (f *Factory) next() int {
	f.seq++
	return f.seq
}

func (f *Factory) insert(sql string, args ...any) int32 {
	f.t.Helper()
	var id int32
	if err := f.pool.QueryRow(context.Background(), sql, args...).Scan(&id); err != nil {
		f.t.Fatalf("factory: %v\n%s", err, sql)
	}
	return id
}

func (f *Factory) exec(sql string, args ...any) {
	f.t.Helper()
	if _, err := f.pool.Exec(context.Background(), sql, args...); err != nil {
		f.t.Fatalf("factory: %v\n%s", err, sql)
	}
}

func (f *Factory) Account(opts ...func(*Account)) Account {
	f.t.Helper()
	a := Account{Name: fmt.Sprintf("Conta %d", f.next())}
	for _, o := range opts {
		o(&a)
	}
	a.ID = f.insert(`INSERT INTO accounts (name, created_at, updated_at) VALUES ($1, now(), now()) RETURNING id`, a.Name)
	return a
}

// User cria o usuário e o vincula à conta.
func (f *Factory) User(account Account, opts ...func(*User)) User {
	f.t.Helper()
	n := f.next()
	u := User{Name: fmt.Sprintf("Agente %d", n), Email: fmt.Sprintf("agente%d@example.com", n)}
	for _, o := range opts {
		o(&u)
	}
	u.ID = f.insert(`INSERT INTO users (name, email, uid, created_at, updated_at) VALUES ($1, $2, $2, now(), now()) RETURNING id`,
		u.Name, u.Email)
	f.exec(`INSERT INTO account_users (account_id, user_id, role, created_at, updated_at) VALUES ($1, $2, $3, now(), now())`,
		account.ID, u.ID, u.Role)
	return u
}

// TelegramInbox cria a inbox e o canal `channel_telegram` que ela aponta.
func (f *Factory) TelegramInbox(account Account, opts ...func(*Inbox)) Inbox {
	f.t.Helper()
	n := f.next()
	in := Inbox{AccountID: account.ID, Name: fmt.Sprintf("Telegram %d", n), BotToken: fmt.Sprintf("%d:token", n)}
	for _, o := range opts {
		o(&in)
	}
	channelID := f.insert(`INSERT INTO channel_telegram (account_id, bot_token, created_at, updated_at) VALUES ($1, $2, now(), now()) RETURNING id`,
		account.ID, in.BotToken)
	in.ID = f.insert(`INSERT INTO inboxes (account_id, name, channel_id, channel_type, created_at, updated_at)
		VALUES ($1, $2, $3, 'Channel::Telegram', now(), now()) RETURNING id`, account.ID, in.Name, channelID)
	return in
}

func (f *Factory) Contact(account Account, opts ...func(*Contact)) Contact {
	f.t.Helper()
	n := f.next()
	c := Contact{AccountID: account.ID, Name: fmt.Sprintf("Contato %d", n), Email: fmt.Sprintf("contato%d@example.com", n)}
	for _, o := range opts {
		o(&c)
	}
	c.ID = f.insert(`INSERT INTO contacts (account_id, name, email, created_at, updated_at) VALUES ($1, $2, $3, now(), now()) RETURNING id`,
		account.ID, c.Name, c.Email)
	return c
}

// Conversation deixa o display_id para o trigger do banco, como no Chatwoot.
func (f *Factory) Conversation(account Account, inbox Inbox, contact Contact, opts ...func(*Conversation)) Conversation {
	f.t.Helper()
	c := Conversation{AccountID: account.ID, InboxID: inbox.ID, ContactID: contact.ID}
	for _, o := range opts {
		o(&c)
	}
	var id, display int32
	err := f.pool.QueryRow(context.Background(), `INSERT INTO conversations (account_id, inbox_id, contact_id, created_at, updated_at)
		VALUES ($1, $2, $3, now(), now()) RETURNING id, display_id`, c.AccountID, c.InboxID, c.ContactID).Scan(&id, &display)
	if err != nil {
		f.t.Fatalf("factory: conversation: %v", err)
	}
	c.ID, c.DisplayID = id, display
	return c
}

func (f *Factory) Message(conv Conversation, opts ...func(*Message)) Message {
	f.t.Helper()
	m := Message{
		ConversationID: conv.ID, AccountID: conv.AccountID, InboxID: conv.InboxID,
		Content: fmt.Sprintf("Mensagem %d", f.next()), Incoming: true,
	}
	for _, o := range opts {
		o(&m)
	}
	messageType := 1 // outgoing
	if m.Incoming {
		messageType = 0
	}
	m.ID = f.insert(`INSERT INTO messages (conversation_id, account_id, inbox_id, message_type, content, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, now(), now()) RETURNING id`, m.ConversationID, m.AccountID, m.InboxID, messageType, m.Content)
	return m
}
