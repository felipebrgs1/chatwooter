package models

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// ContactUpdate são os permitted_params do update; nil = campo ausente no pedido (não muda).
// Os dois mapas de atributos são mesclados sobre os existentes (contact_update_params).
type ContactUpdate struct {
	Name                 *string
	Identifier           *string
	Email                *string
	PhoneNumber          *string
	Blocked              *bool
	AdditionalAttributes map[string]any
	CustomAttributes     map[string]any
}

// ValidationError é o ActiveRecord::RecordInvalid: mensagens completas e os atributos, na ordem do Rails.
type ValidationError struct {
	Messages   []string
	Attributes []string
}

func (e *ValidationError) Error() string { return strings.Join(e.Messages, ", ") }

func (e *ValidationError) add(attribute, message string) {
	e.Messages = append(e.Messages, message)
	for _, a := range e.Attributes {
		if a == attribute {
			return
		}
	}
	e.Attributes = append(e.Attributes, attribute)
}

var (
	// Devise.email_regexp configurado no Chatwoot
	emailFormat = regexp.MustCompile(`\A[^@\s]+@[^@\s]+\z`)
	e164Format  = regexp.MustCompile(`\A\+[1-9]\d{1,14}\z`)
)

type contactRow struct {
	email, phone, identifier *string
	additional, custom       map[string]any
	contactType              int32
}

// Update aplica o update do ContactsController: before_validation (e-mail em minúsculas, vazio vira nil),
// as validações do Contact e o before_save do Contacts::SyncAttributes (location, country_code, contact_type).
// Os eventos CONTACT_UPDATED (webhooks, tempo real) ainda não existem aqui.
func (c *Contacts) Update(ctx context.Context, accountID, id int32, in ContactUpdate) (Contact, error) {
	tx, err := c.db.Begin(ctx)
	if err != nil {
		return Contact{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var cur contactRow
	var addRaw, customRaw []byte
	var name *string
	var blocked bool
	err = tx.QueryRow(ctx, `SELECT name, email, phone_number, identifier, blocked, COALESCE(additional_attributes, '{}'),
		COALESCE(custom_attributes, '{}'), COALESCE(contact_type, 0)
		FROM contacts WHERE account_id = $1 AND id = $2 FOR UPDATE`, accountID, id).
		Scan(&name, &cur.email, &cur.phone, &cur.identifier, &blocked, &addRaw, &customRaw, &cur.contactType)
	if errors.Is(err, pgx.ErrNoRows) {
		return Contact{}, ErrNotFound
	}
	if err != nil {
		return Contact{}, err
	}
	if err := json.Unmarshal(addRaw, &cur.additional); err != nil {
		return Contact{}, err
	}
	if err := json.Unmarshal(customRaw, &cur.custom); err != nil {
		return Contact{}, err
	}

	if in.Name != nil {
		name = in.Name
	}
	if in.Blocked != nil {
		blocked = *in.Blocked
	}
	if in.Identifier != nil {
		cur.identifier = in.Identifier
	}
	if in.PhoneNumber != nil {
		cur.phone = in.PhoneNumber
	}
	if in.Email != nil {
		cur.email = in.Email
	}
	// prepare_email_attribute: presente → minúsculas; em branco → nil (o índice único não aceita '')
	if cur.email != nil {
		if strings.TrimSpace(*cur.email) == "" {
			cur.email = nil
		} else {
			lower := strings.ToLower(*cur.email)
			cur.email = &lower
		}
	}
	// identifier em branco vira NULL: com '' dois contatos colidiriam no índice único (no Rails, um 500)
	cur.identifier = blankToNil(cur.identifier)
	for k, v := range in.AdditionalAttributes {
		cur.additional[k] = v
	}
	for k, v := range in.CustomAttributes {
		cur.custom[k] = v
	}

	if invalid, err := c.validate(ctx, tx, accountID, id, cur); err != nil {
		return Contact{}, err
	} else if invalid != nil {
		return Contact{}, invalid
	}

	additional, err := json.Marshal(cur.additional)
	if err != nil {
		return Contact{}, err
	}
	custom, err := json.Marshal(cur.custom)
	if err != nil {
		return Contact{}, err
	}
	_, err = tx.Exec(ctx, `UPDATE contacts SET name = $3, email = $4, phone_number = $5, identifier = $6, blocked = $7,
		additional_attributes = $8, custom_attributes = $9, location = $10, country_code = $11, contact_type = $12, updated_at = now()
		WHERE account_id = $1 AND id = $2`,
		accountID, id, name, cur.email, cur.phone, cur.identifier, blocked, additional, custom,
		stringAttr(cur.additional, "city"), stringAttr(cur.additional, "country"), syncedContactType(cur))
	if uniqueViolation(err) {
		// corrida entre a validação e o índice único: o Rails devolveria o mesmo 422 na próxima tentativa
		invalid := &ValidationError{}
		invalid.add("email", "Email has already been taken")
		return Contact{}, invalid
	}
	if err != nil {
		return Contact{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return Contact{}, err
	}
	return c.Get(ctx, accountID, id, true)
}

// validate roda os validates do Contact na ordem em que foram declarados: e-mail (unicidade sem distinguir
// maiúsculas, formato), identifier (unicidade) e telefone (unicidade, E.164). allow_blank pula os vazios.
func (c *Contacts) validate(ctx context.Context, tx pgx.Tx, accountID, id int32, cur contactRow) (*ValidationError, error) {
	invalid := &ValidationError{}
	taken := func(column, value string, caseInsensitive bool) (bool, error) {
		cond := column + " = $3"
		if caseInsensitive {
			cond = "lower(" + column + ") = lower($3)"
		}
		var exists bool
		err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM contacts WHERE account_id = $1 AND id <> $2 AND `+cond+`)`,
			accountID, id, value).Scan(&exists)
		return exists, err
	}
	if v := blankToNil(cur.email); v != nil {
		exists, err := taken("email", *v, true)
		if err != nil {
			return nil, err
		}
		if exists {
			invalid.add("email", "Email has already been taken")
		}
		if !emailFormat.MatchString(*v) {
			invalid.add("email", "Email Invalid email")
		}
	}
	if v := blankToNil(cur.identifier); v != nil {
		exists, err := taken("identifier", *v, false)
		if err != nil {
			return nil, err
		}
		if exists {
			invalid.add("identifier", "Identifier has already been taken")
		}
	}
	if v := blankToNil(cur.phone); v != nil {
		exists, err := taken("phone_number", *v, false)
		if err != nil {
			return nil, err
		}
		if exists {
			invalid.add("phone_number", "Phone number has already been taken")
		}
		if !e164Format.MatchString(*v) {
			invalid.add("phone_number", "Phone number should be in e164 format")
		}
	}
	if len(invalid.Messages) == 0 {
		return nil, nil
	}
	return invalid, nil
}

func blankToNil(s *string) *string {
	if s == nil || strings.TrimSpace(*s) == "" {
		return nil
	}
	return s
}

func stringAttr(attrs map[string]any, key string) *string {
	if s, ok := attrs[key].(string); ok {
		return &s
	}
	return nil
}

// syncedContactType é o set_contact_type: visitor (0) vira lead (1) com e-mail, telefone ou algum social_* preenchido.
func syncedContactType(cur contactRow) int32 {
	if cur.contactType != 0 {
		return cur.contactType
	}
	if blankToNil(cur.email) != nil || blankToNil(cur.phone) != nil {
		return 1
	}
	for k, v := range cur.additional {
		if strings.HasPrefix(k, "social_") && present(v) {
			return 1
		}
	}
	return 0
}

// present é o `present?` do Rails para valores JSON.
func present(v any) bool {
	switch val := v.(type) {
	case nil:
		return false
	case string:
		return strings.TrimSpace(val) != ""
	case map[string]any:
		return len(val) > 0
	case []any:
		return len(val) > 0
	case bool:
		return val
	}
	return true
}

func uniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

// Delete é o destroy: o Rails apaga o contato e as taggings na hora e o resto por destroy_async
// (conversas, contact_inboxes, notas, mensagens do contato, CSAT e, em cascata, o que pende das conversas e
// mensagens). Aqui tudo sai numa transação só, com o mesmo estado final. Arquivos no storage (avatar e anexos)
// e o evento CONTACT_DELETED ainda não existem; a checagem de contato online (OnlineStatusTracker) também não.
func (c *Contacts) Delete(ctx context.Context, accountID, id int32) error {
	tx, err := c.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var exists bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM contacts WHERE account_id = $1 AND id = $2)`, accountID, id).
		Scan(&exists); err != nil {
		return err
	}
	if !exists {
		return ErrNotFound
	}
	// Conversas do contato (direto ou pelos contact_inboxes) e mensagens delas ou enviadas pelo contato.
	scope := []any{accountID, id}
	steps := []struct {
		sql  string
		args []any
	}{
		{`CREATE TEMP TABLE gone_conversations ON COMMIT DROP AS SELECT id FROM conversations
			WHERE account_id = $1 AND (contact_id = $2 OR contact_inbox_id IN (SELECT id FROM contact_inboxes WHERE contact_id = $2))`, scope},
		{`CREATE TEMP TABLE gone_messages ON COMMIT DROP AS SELECT id FROM messages
			WHERE account_id = $1 AND (conversation_id IN (SELECT id FROM gone_conversations) OR (sender_type = 'Contact' AND sender_id = $2))`, scope},
		{`DELETE FROM chatwooter_attachment_storage WHERE message_id IN (SELECT id FROM gone_messages)`, nil},
		{`DELETE FROM attachments WHERE message_id IN (SELECT id FROM gone_messages)`, nil},
		{`DELETE FROM notifications WHERE (primary_actor_type = 'Conversation' AND primary_actor_id IN (SELECT id FROM gone_conversations))
			OR (primary_actor_type = 'Message' AND primary_actor_id IN (SELECT id FROM gone_messages))`, nil},
		{`DELETE FROM csat_survey_responses WHERE contact_id = $1 OR conversation_id IN (SELECT id FROM gone_conversations)
			OR message_id IN (SELECT id FROM gone_messages)`, []any{id}},
		{`DELETE FROM mentions WHERE conversation_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM conversation_participants WHERE conversation_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM reporting_events WHERE conversation_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM automation_rule_pending_executions WHERE conversation_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM taggings WHERE taggable_type = 'Conversation' AND taggable_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM messages WHERE id IN (SELECT id FROM gone_messages)`, nil},
		{`DELETE FROM conversations WHERE id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM contact_inboxes WHERE contact_id = $1`, []any{id}},
		{`DELETE FROM notes WHERE contact_id = $1`, []any{id}},
		{`DELETE FROM taggings WHERE taggable_type = 'Contact' AND taggable_id = $1`, []any{id}},
		{`DELETE FROM contacts WHERE account_id = $1 AND id = $2`, scope},
	}
	for _, step := range steps {
		if _, err := tx.Exec(ctx, step.sql, step.args...); err != nil {
			return fmt.Errorf("excluir contato: %w", err)
		}
	}
	return tx.Commit(ctx)
}
