package views

import (
	"encoding/json"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

// ContactJSON espelha api/v1/models/_contact.json.jbuilder.
type ContactJSON struct {
	AdditionalAttributes json.RawMessage `json:"additional_attributes"`
	AvailabilityStatus   string          `json:"availability_status"`
	Email                *string         `json:"email"`
	ID                   int32           `json:"id"`
	Name                 string          `json:"name"`
	PhoneNumber          *string         `json:"phone_number"`
	Blocked              bool            `json:"blocked"`
	Identifier           *string         `json:"identifier"`
	Thumbnail            string          `json:"thumbnail"`
	CustomAttributes     json.RawMessage `json:"custom_attributes"`
	LastActivityAt       *int64          `json:"last_activity_at,omitempty"`
	CreatedAt            int64           `json:"created_at,omitempty"`
	// v1 habilita companies em todas as contas, como as rotas de empresas.
	CompanyID *int64 `json:"company_id"`
	// contact_inboxes só nos endpoints de /contacts (with_contact_inboxes); nil = ausente.
	ContactInboxes *[]ContactInboxJSON `json:"contact_inboxes,omitempty"`
}

// ContactInboxJSON espelha _contact_inbox.json.jbuilder.
type ContactInboxJSON struct {
	SourceID string        `json:"source_id"`
	Inbox    InboxSlimJSON `json:"inbox"`
}

// InboxSlimJSON espelha _inbox_slim.json.jbuilder (sem avatar ainda: avatar_url vazio, como o Avatarable).
type InboxSlimJSON struct {
	ID          int32   `json:"id"`
	AvatarURL   string  `json:"avatar_url"`
	ChannelID   int32   `json:"channel_id"`
	Name        string  `json:"name"`
	ChannelType string  `json:"channel_type"`
	Provider    *string `json:"provider"`
}

func Contact(c models.Contact) ContactJSON {
	out := ContactJSON{
		AdditionalAttributes: c.AdditionalAttributes,
		CompanyID:            c.CompanyID,
		// Sem presença de contatos ainda: todo contato aparece offline.
		AvailabilityStatus: "offline",
		Email:              nilIfEmpty(c.Email),
		ID:                 c.ID,
		Name:               c.Name,
		PhoneNumber:        nilIfEmpty(c.PhoneNumber),
		Blocked:            c.Blocked,
		Identifier:         nilIfEmpty(c.Identifier),
		CustomAttributes:   c.CustomAttributes,
		CreatedAt:          c.CreatedAt.Unix(),
	}
	if c.LastActivityAt != nil {
		v := c.LastActivityAt.Unix()
		out.LastActivityAt = &v
	}
	if c.ContactInboxes != nil {
		cis := make([]ContactInboxJSON, 0, len(*c.ContactInboxes))
		for _, ci := range *c.ContactInboxes {
			cis = append(cis, ContactInboxJSON{SourceID: ci.SourceID, Inbox: InboxSlimJSON{
				ID: ci.Inbox.ID, ChannelID: ci.Inbox.ChannelID, Name: ci.Inbox.Name,
				ChannelType: ci.Inbox.ChannelType, Provider: ci.Inbox.Provider,
			}})
		}
		out.ContactInboxes = &cis
	}
	return out
}

// AgentJSON espelha api/v1/models/_agent.json.jbuilder.
type AgentJSON struct {
	ID                 int32  `json:"id"`
	AccountID          int32  `json:"account_id"`
	AvailabilityStatus string `json:"availability_status"`
	AutoOffline        bool   `json:"auto_offline"`
	Confirmed          bool   `json:"confirmed"`
	Email              string `json:"email"`
	Provider           string `json:"provider"`
	AvailableName      string `json:"available_name"`
	Name               string `json:"name"`
	Role               string `json:"role"`
	Thumbnail          string `json:"thumbnail"`
}

func Agent(a models.Agent) AgentJSON {
	return AgentJSON{
		ID: a.ID, AccountID: a.AccountID, AvailabilityStatus: a.AvailabilityStatus, AutoOffline: a.AutoOffline,
		Confirmed: a.Confirmed, Email: a.Email, Provider: a.Provider, AvailableName: a.AvailableName,
		Name: a.Name, Role: a.Role,
	}
}

// TeamJSON espelha api/v1/models/_team.json.jbuilder.
type TeamJSON struct {
	ID              int32   `json:"id"`
	Name            string  `json:"name"`
	Description     *string `json:"description"`
	AllowAutoAssign bool    `json:"allow_auto_assign"`
	Icon            string  `json:"icon"`
	IconColor       string  `json:"icon_color"`
	AccountID       int32   `json:"account_id"`
	IsMember        bool    `json:"is_member"`
}

func Team(t models.Team) TeamJSON {
	return TeamJSON{
		ID: t.ID, Name: t.Name, Description: nilIfEmpty(t.Description), AllowAutoAssign: t.AllowAutoAssign,
		Icon: t.Icon, IconColor: t.IconColor, AccountID: t.AccountID, IsMember: t.IsMember,
	}
}

// AssignableAgents espelha api/v1/accounts/assignable_agents/index.json.jbuilder (só usuários).
func AssignableAgents(list []models.Agent) map[string][]AgentJSON {
	out := make([]AgentJSON, 0, len(list))
	for _, a := range list {
		out = append(out, Agent(a))
	}
	return map[string][]AgentJSON{"payload": out}
}
