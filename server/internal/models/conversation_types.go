package models

import (
	"encoding/json"
	"time"
)

type Contact struct {
	CompanyID            *int64
	ID                   int32
	Name                 string
	Email                string
	PhoneNumber          string
	Identifier           string
	Blocked              bool
	AdditionalAttributes json.RawMessage
	CustomAttributes     json.RawMessage
	CreatedAt            time.Time
	LastActivityAt       *time.Time
	// ContactInboxes só vem quando pedido (include_contact_inboxes); nil = não carregado.
	ContactInboxes *[]ContactInbox
}

// Agent é um usuário visto como membro de uma conta (api/v1/models/_agent.json.jbuilder).
type Agent struct {
	ID                 int32
	AccountID          int32
	AvailabilityStatus string
	AutoOffline        bool
	Confirmed          bool
	Email              string
	Provider           string
	AvailableName      string
	Name               string
	Role               string
}

type Team struct {
	ID              int32
	AccountID       int32
	Name            string
	Description     string
	AllowAutoAssign bool
	Icon            string
	IconColor       string
	IsMember        bool
}

type Attachment struct {
	ID        int32
	MessageID int32
	AccountID int32
	FileType  string
	Extension string
	DataURL   string
	ThumbURL  string
	FileSize  int32
}

// Sender é quem escreveu a mensagem: usuário (agente) ou contato.
type Sender struct {
	ID                 int32
	Type               string // user | contact
	Name               string
	AvailableName      string
	Email              string
	PhoneNumber        string
	Identifier         string
	Blocked            bool
	AvailabilityStatus string
	AdditionalAttrs    json.RawMessage
	CustomAttrs        json.RawMessage
}

type Message struct {
	ID                int32
	Content           *string
	InboxID           int32
	EchoID            string
	ConversationID    int32 // display_id da conversa
	MessageType       int32 // 0 incoming, 1 outgoing, 2 activity, 3 template
	ContentType       string
	Status            string
	ContentAttributes json.RawMessage
	CreatedAt         time.Time
	Private           bool
	SourceID          *string
	Sender            *Sender
	Attachments       []Attachment
}

// ConversationItem é a conversa como a lista e a thread a consomem.
type ConversationItem struct {
	ID                  int32 // display_id
	InternalID          int32
	AccountID           int32
	UUID                string
	InboxID             int32
	Status              string
	Priority            *string
	SnoozedUntil        *time.Time
	UnreadCount         int
	Labels              []string
	AdditionalAttrs     json.RawMessage
	CustomAttrs         json.RawMessage
	AgentLastSeenAt     *time.Time
	AssigneeLastSeenAt  *time.Time
	ContactLastSeenAt   *time.Time
	FirstReplyCreatedAt *time.Time
	CreatedAt           time.Time
	UpdatedAt           time.Time
	LastActivityAt      time.Time
	WaitingSince        *time.Time
	SLAPolicyID         *int64
	Contact             Contact
	Channel             string
	Assignee            *Agent
	Team                *Team
	LastMessage         *Message
	LastNonActivity     *Message
}

type ConversationFilter struct {
	UserID           int32  // quem consulta (abas "mine", menções, participações)
	Status           string // open (padrão) | resolved | pending | snoozed | all
	AssigneeType     string // me | assigned | unassigned | all (padrão)
	InboxID          int32
	TeamID           int32
	Label            string
	ConversationType string // mention | participating | unattended
	SortBy           string
	Page             int
	// OnlyInboxesOfUser (id de usuário) restringe às inboxes de que ele é membro: é o que agentes veem.
	// Administradores deixam 0 e veem todas.
	OnlyInboxesOfUser int32
}

type ConversationCounts struct {
	Mine       int
	Assigned   int
	Unassigned int
	All        int
}

const conversationsPageSize = 25
