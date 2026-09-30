package models

import (
	"context"
	"encoding/json"
	"strings"
)

// ProfileUpdate traz só o que mudou (nil = não altera). E-mail e senha ficam de fora até existir o fluxo de confirmação.
type ProfileUpdate struct {
	Name             *string
	DisplayName      *string
	MessageSignature *string
	// UISettings substitui o objeto inteiro, como no Chatwoot (o cliente envia o objeto já mesclado).
	UISettings json.RawMessage
}

func (u *Users) UpdateProfile(ctx context.Context, id int32, in ProfileUpdate) error {
	if in.Name != nil && strings.TrimSpace(*in.Name) == "" {
		return ErrInvalid
	}
	var ui []byte
	if in.UISettings != nil {
		var obj map[string]any
		if json.Unmarshal(in.UISettings, &obj) != nil || obj == nil {
			return ErrInvalid
		}
		ui = in.UISettings
	}
	_, err := u.db.Exec(ctx, `UPDATE users SET
		name = COALESCE($2, name),
		display_name = CASE WHEN $3::text IS NULL THEN display_name ELSE NULLIF($3, '') END,
		message_signature = COALESCE($4, message_signature),
		ui_settings = COALESCE($5::jsonb, ui_settings),
		updated_at = now() AT TIME ZONE 'utc'
		WHERE id = $1`, id, in.Name, in.DisplayName, in.MessageSignature, ui)
	return err
}

var availabilityValues = map[string]int32{"online": 0, "offline": 1, "busy": 2}

func (u *Users) SetAvailability(ctx context.Context, userID, accountID int32, availability string) error {
	value, ok := availabilityValues[availability]
	if !ok {
		return ErrInvalid
	}
	return u.updateMembership(ctx, userID, accountID, "availability = $3", value)
}

func (u *Users) SetAutoOffline(ctx context.Context, userID, accountID int32, autoOffline bool) error {
	return u.updateMembership(ctx, userID, accountID, "auto_offline = $3", autoOffline)
}

// SetActiveAccount marca a conta como a mais recente; é dela que o perfil tira `account_id`.
func (u *Users) SetActiveAccount(ctx context.Context, userID, accountID int32) error {
	return u.updateMembership(ctx, userID, accountID, "active_at = now() AT TIME ZONE 'utc'")
}

func (u *Users) updateMembership(ctx context.Context, userID, accountID int32, set string, args ...any) error {
	tag, err := u.db.Exec(ctx, `UPDATE account_users SET `+set+`, updated_at = now() AT TIME ZONE 'utc'
		WHERE user_id = $1 AND account_id = $2`, append([]any{userID, accountID}, args...)...)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
