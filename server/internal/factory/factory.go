// Package factory monta dados de teste reais no Postgres (equivale ao ExMachina do app Elixir).
// Cada construtor recebe mutadores opcionais que alteram os defaults antes do INSERT.
package factory

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type Account struct {
	ID   int32
	Name string
}

// DefaultPassword é a senha dos usuários criados pela factory, salvo se Password for alterada.
const DefaultPassword = "Password1!"

type User struct {
	ID    int32
	Name  string
	Email string
	// UID é a identidade do provider; por padrão igual ao e-mail (Devise).
	UID      string
	Password string
	Role     int32 // 0 agent, 1 administrator
	// AccessToken é o `api_access_token` do usuário (tabela access_tokens).
	AccessToken string
}

func (u User) uid() string {
	if u.UID != "" {
		return u.UID
	}
	return u.Email
}

type Inbox struct {
	ID        int32
	AccountID int32
	Name      string
	BotToken  string
	BotName   *string
	// Phone é o número do canal WhatsApp.
	Phone string
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
	Status    int32 // 0 open, 1 resolved, 2 pending, 3 snoozed
	Priority  *int32
	// AssigneeID e TeamID ficam nulos por padrão (sem responsável).
	AssigneeID *int32
	TeamID     *int32
	// LastActivityAt padrão: agora. Testes de ordenação definem valores distintos.
	LastActivityAt *time.Time
	AgentLastSeen  *time.Time
	CachedLabels   string
}

type Team struct {
	ID        int32
	AccountID int32
	Name      string
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

// Pool dá acesso ao banco para testes que precisam montar um caso específico.
func (f *Factory) Pool() *pgxpool.Pool { return f.pool }

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
	u := User{
		Name: fmt.Sprintf("Agente %d", n), Email: fmt.Sprintf("agente%d@example.com", n), Password: DefaultPassword,
		AccessToken: fmt.Sprintf("token-agente-%d", n),
	}
	for _, o := range opts {
		o(&u)
	}
	// Custo mínimo: os testes criam muitos usuários e o custo padrão do bcrypt os deixaria lentos.
	hash, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.MinCost)
	if err != nil {
		f.t.Fatal(err)
	}
	u.ID = f.insert(`INSERT INTO users (name, email, uid, encrypted_password, confirmed_at, created_at, updated_at)
		VALUES ($1, $2, $4, $3, now(), now(), now()) RETURNING id`, u.Name, u.Email, string(hash), u.uid())
	f.exec(`INSERT INTO access_tokens (owner_type, owner_id, token, created_at, updated_at) VALUES ('User', $1, $2, now(), now())`,
		u.ID, u.AccessToken)
	f.exec(`INSERT INTO account_users (account_id, user_id, role, created_at, updated_at) VALUES ($1, $2, $3, now(), now())`,
		account.ID, u.ID, u.Role)
	return u
}

// Member vincula um usuário existente a outra conta.
func (f *Factory) Member(account Account, user User, role int32) {
	f.t.Helper()
	f.exec(`INSERT INTO account_users (account_id, user_id, role, created_at, updated_at) VALUES ($1, $2, $3, now(), now())`,
		account.ID, user.ID, role)
}

// TelegramInbox cria a inbox e o canal `channel_telegram` que ela aponta.
func (f *Factory) TelegramInbox(account Account, opts ...func(*Inbox)) Inbox {
	f.t.Helper()
	n := f.next()
	in := Inbox{AccountID: account.ID, Name: fmt.Sprintf("Telegram %d", n), BotToken: fmt.Sprintf("%d:token", n)}
	for _, o := range opts {
		o(&in)
	}
	channelID := f.insert(`INSERT INTO channel_telegram (account_id, bot_token, bot_name, created_at, updated_at) VALUES ($1, $2, $3, now(), now()) RETURNING id`,
		account.ID, in.BotToken, in.BotName)
	in.ID = f.insert(`INSERT INTO inboxes (account_id, name, channel_id, channel_type, created_at, updated_at)
		VALUES ($1, $2, $3, 'Channel::Telegram', now(), now()) RETURNING id`, account.ID, in.Name, channelID)
	return in
}

// WhatsappInbox cria a inbox e o canal `channel_whatsapp` (provedor cloud).
func (f *Factory) WhatsappInbox(account Account, opts ...func(*Inbox)) Inbox {
	f.t.Helper()
	n := f.next()
	in := Inbox{AccountID: account.ID, Name: fmt.Sprintf("WhatsApp %d", n), Phone: fmt.Sprintf("+55119%08d", n)}
	for _, o := range opts {
		o(&in)
	}
	channelID := f.insert(`INSERT INTO channel_whatsapp (account_id, phone_number, provider, created_at, updated_at)
		VALUES ($1, $2, 'whatsapp_cloud', now(), now()) RETURNING id`, account.ID, in.Phone)
	in.ID = f.insert(`INSERT INTO inboxes (account_id, name, channel_id, channel_type, created_at, updated_at)
		VALUES ($1, $2, $3, 'Channel::Whatsapp', now(), now()) RETURNING id`, account.ID, in.Name, channelID)
	return in
}

// WorkingHour grava o expediente de um dia da inbox (working_hours).
func (f *Factory) WorkingHour(inbox Inbox, day, openHour, closeHour int32) {
	f.t.Helper()
	f.exec(`INSERT INTO working_hours (inbox_id, account_id, day_of_week, open_hour, open_minutes, close_hour, close_minutes, created_at, updated_at)
		VALUES ($1, $2, $3, $4, 0, $5, 0, now(), now())`, inbox.ID, inbox.AccountID, day, openHour, closeHour)
}

// InboxMember torna o usuário agente da inbox.
func (f *Factory) InboxMember(inbox Inbox, user User) {
	f.t.Helper()
	f.exec(`INSERT INTO inbox_members (inbox_id, user_id, created_at, updated_at) VALUES ($1, $2, now(), now())`, inbox.ID, user.ID)
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
	err := f.pool.QueryRow(context.Background(), `INSERT INTO conversations
		(account_id, inbox_id, contact_id, status, priority, assignee_id, team_id, last_activity_at, agent_last_seen_at, cached_label_list, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8, now() AT TIME ZONE 'utc'), $9, $10, now(), now()) RETURNING id, display_id`,
		c.AccountID, c.InboxID, c.ContactID, c.Status, c.Priority, c.AssigneeID, c.TeamID, c.LastActivityAt, c.AgentLastSeen, c.CachedLabels).Scan(&id, &display)
	if err != nil {
		f.t.Fatalf("factory: conversation: %v", err)
	}
	c.ID, c.DisplayID = id, display
	return c
}

func (f *Factory) Team(account Account, opts ...func(*Team)) Team {
	f.t.Helper()
	tm := Team{AccountID: account.ID, Name: fmt.Sprintf("Time %d", f.next())}
	for _, o := range opts {
		o(&tm)
	}
	tm.ID = f.insert(`INSERT INTO teams (account_id, name, created_at, updated_at) VALUES ($1, $2, now(), now()) RETURNING id`, tm.AccountID, tm.Name)
	return tm
}

// TeamMember coloca o usuário no time (team_members).
func (f *Factory) TeamMember(team Team, user User) {
	f.t.Helper()
	f.exec(`INSERT INTO team_members (team_id, user_id, created_at, updated_at) VALUES ($1, $2, now(), now())`, team.ID, user.ID)
}

type AccountLabel struct {
	ID            int32
	AccountID     int32
	Title         string
	Color         string
	Description   *string
	ShowOnSidebar bool
}

// AccountLabel cria a etiqueta da conta (tabela labels), a que dá cor e aparece na sidebar.
func (f *Factory) AccountLabel(account Account, opts ...func(*AccountLabel)) AccountLabel {
	f.t.Helper()
	l := AccountLabel{AccountID: account.ID, Title: fmt.Sprintf("etiqueta-%d", f.next()), Color: "#1f93ff", ShowOnSidebar: true}
	for _, o := range opts {
		o(&l)
	}
	l.ID = f.insert(`INSERT INTO labels (account_id, title, color, description, show_on_sidebar, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, now(), now()) RETURNING id`, l.AccountID, l.Title, l.Color, l.Description, l.ShowOnSidebar)
	return l
}

// Label etiqueta a conversa como o Chatwoot (acts_as_taggable_on): tags + taggings + cached_label_list.
func (f *Factory) Label(conv Conversation, title string) {
	f.t.Helper()
	tagID := f.insert(`INSERT INTO tags (name, taggings_count) VALUES ($1, 1) ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id`, title)
	f.exec(`INSERT INTO taggings (tag_id, taggable_type, taggable_id, context, created_at) VALUES ($1, 'Conversation', $2, 'labels', now())`, tagID, conv.ID)
	f.exec(`UPDATE conversations SET cached_label_list = concat_ws(', ', NULLIF(cached_label_list, ''), $2::text) WHERE id = $1`, conv.ID, title)
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
