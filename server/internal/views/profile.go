package views

import (
	"encoding/json"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

// ProfileJSON espelha app/views/api/v1/models/_user.json.jbuilder (via devise/auth.json.jbuilder).
type ProfileJSON struct {
	AccessToken      string           `json:"access_token"`
	AccountID        *int32           `json:"account_id"`
	AvailableName    string           `json:"available_name"`
	AvatarURL        string           `json:"avatar_url"`
	Confirmed        bool             `json:"confirmed"`
	DisplayName      *string          `json:"display_name"`
	MessageSignature *string          `json:"message_signature"`
	Email            string           `json:"email"`
	ID               int32            `json:"id"`
	InviterID        *int32           `json:"inviter_id"`
	Name             string           `json:"name"`
	Provider         string           `json:"provider"`
	PubsubToken      string           `json:"pubsub_token"`
	CustomAttributes json.RawMessage  `json:"custom_attributes,omitempty"`
	Role             *string          `json:"role"`
	UISettings       json.RawMessage  `json:"ui_settings"`
	UID              string           `json:"uid"`
	Type             *string          `json:"type"`
	Accounts         []ProfileAccount `json:"accounts"`
}

type ProfileAccount struct {
	ID                 int32    `json:"id"`
	Name               string   `json:"name"`
	Status             string   `json:"status"`
	OnboardingStep     *string  `json:"onboarding_step"`
	ActiveAt           *string  `json:"active_at"`
	Role               string   `json:"role"`
	Permissions        []string `json:"permissions"`
	Availability       string   `json:"availability"`
	AvailabilityStatus string   `json:"availability_status"`
	AutoOffline        bool     `json:"auto_offline"`
	APIAndWebhooks     bool     `json:"api_and_webhooks"`
}

func Profile(p models.Profile) ProfileJSON {
	out := ProfileJSON{
		AccessToken:      p.AccessToken,
		AccountID:        p.ActiveAccountID,
		AvailableName:    p.User.AvailableName(),
		Confirmed:        p.User.Confirmed,
		DisplayName:      nilIfEmpty(p.User.DisplayName),
		MessageSignature: nilIfEmpty(p.User.MessageSignature),
		Email:            p.User.Email,
		ID:               p.User.ID,
		Name:             p.User.Name,
		Provider:         p.User.Provider,
		PubsubToken:      p.User.PubsubToken,
		UISettings:       p.User.UISettings,
		UID:              p.User.UID,
		Type:             nilIfEmpty(p.User.Type),
		Accounts:         make([]ProfileAccount, 0, len(p.Memberships)),
	}
	if string(p.User.CustomAttributes) != "{}" {
		out.CustomAttributes = p.User.CustomAttributes
	}
	for _, m := range p.Memberships {
		out.Accounts = append(out.Accounts, ProfileAccount{
			ID:             m.AccountID,
			Name:           m.AccountName,
			Status:         m.AccountStatus,
			OnboardingStep: nilIfEmpty(m.OnboardingStep),
			ActiveAt:       railsTimePtr(m.ActiveAt),
			Role:           m.Role,
			Permissions:    m.Permissions(),
			Availability:   m.Availability,
			// Sem presença em tempo real ainda (Fase 4): o status derivado é a disponibilidade configurada.
			AvailabilityStatus: m.Availability,
			AutoOffline:        m.AutoOffline,
			// Self-hosted: todos os recursos estão habilitados.
			APIAndWebhooks: true,
		})
		if p.ActiveAccountID != nil && m.AccountID == *p.ActiveAccountID {
			role, inviter := m.Role, m.InviterID
			out.Role, out.InviterID = &role, inviter
		}
	}
	return out
}

// SignIn é a resposta do devise_token_auth: o perfil dentro de "data".
func SignIn(p models.Profile) map[string]any { return map[string]any{"data": Profile(p)} }
