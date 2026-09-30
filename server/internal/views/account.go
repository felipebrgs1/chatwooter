package views

import (
	"encoding/json"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

// AccountJSON espelha api/v1/accounts/show.json.jbuilder.
type AccountJSON struct {
	Settings         json.RawMessage `json:"settings"`
	CreatedAt        string          `json:"created_at"`
	CustomAttributes json.RawMessage `json:"custom_attributes,omitempty"`
	Domain           *string         `json:"domain"`
	// Features ainda não tem origem (feature_flags é bitmask do Rails); a lista vazia esconde o que depende dela.
	Features     []string          `json:"features"`
	ID           int32             `json:"id"`
	Locale       string            `json:"locale"`
	Name         string            `json:"name"`
	SupportEmail *string           `json:"support_email"`
	Status       string            `json:"status"`
	CacheKeys    map[string]string `json:"cache_keys"`
}

func Account(a models.Account) AccountJSON {
	out := AccountJSON{
		Settings:     a.Settings,
		CreatedAt:    railsTime(a.CreatedAt),
		Domain:       nilIfEmpty(a.Domain),
		Features:     []string{},
		ID:           a.ID,
		Locale:       a.Locale,
		Name:         a.Name,
		SupportEmail: nilIfEmpty(a.SupportEmail),
		Status:       a.Status,
		CacheKeys:    map[string]string{},
	}
	if string(a.CustomAttributes) != "{}" {
		out.CustomAttributes = a.CustomAttributes
	}
	return out
}
