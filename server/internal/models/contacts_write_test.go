package models_test

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func strp(s string) *string { return &s }

func TestContactUpdateMergesAttributesAndNormalizes(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	account := f.Account()
	ct := f.Contact(account, func(c *factory.Contact) {
		c.Email = ""
		c.AdditionalAttributes = `{"city": "Recife", "company_name": "Velha"}`
	})

	got, err := models.NewContacts(pool).Update(ctx, account.ID, ct.ID, models.ContactUpdate{
		Name:                 strp("Ana Nova"),
		Email:                strp("Ana@Example.COM"),
		PhoneNumber:          strp("+5511999990000"),
		AdditionalAttributes: map[string]any{"company_name": "Nova", "country": "Brazil"},
		CustomAttributes:     map[string]any{"plano": "ouro"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if got.Name != "Ana Nova" || got.Email != "ana@example.com" || got.PhoneNumber != "+5511999990000" {
		t.Fatalf("campos: %+v", got)
	}
	if string(got.AdditionalAttributes) != `{"city": "Recife", "country": "Brazil", "company_name": "Nova"}` {
		t.Fatalf("additional_attributes mesclado: %s", got.AdditionalAttributes)
	}
	if got.ContactInboxes == nil {
		t.Fatal("update devolve os contact_inboxes (include padrão)")
	}
	var location, country string
	var contactType int
	if err := pool.QueryRow(ctx, `SELECT location, country_code, contact_type FROM contacts WHERE id = $1`, ct.ID).
		Scan(&location, &country, &contactType); err != nil {
		t.Fatal(err)
	}
	if location != "Recife" || country != "Brazil" || contactType != 1 {
		t.Fatalf("Contacts::SyncAttributes: location=%q country_code=%q contact_type=%d", location, country, contactType)
	}
}

func TestContactUpdateValidationErrors(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	account := f.Account()
	f.Contact(account, func(c *factory.Contact) { c.Email, c.Phone, c.Identifier = "dono@x.com", "+5511911112222", "ext-1" })
	ct := f.Contact(account)
	contacts := models.NewContacts(pool)

	_, err := contacts.Update(ctx, account.ID, ct.ID, models.ContactUpdate{
		Email: strp("DONO@x.com"), PhoneNumber: strp("+5511911112222"), Identifier: strp("ext-1"),
	})
	var invalid *models.ValidationError
	if !errors.As(err, &invalid) {
		t.Fatalf("esperava ValidationError, veio %v", err)
	}
	wantMsgs := []string{"Email has already been taken", "Identifier has already been taken", "Phone number has already been taken"}
	if !reflect.DeepEqual(invalid.Messages, wantMsgs) || !reflect.DeepEqual(invalid.Attributes, []string{"email", "identifier", "phone_number"}) {
		t.Fatalf("erros: %+v", invalid)
	}

	_, err = contacts.Update(ctx, account.ID, ct.ID, models.ContactUpdate{Email: strp("sem-arroba"), PhoneNumber: strp("11999")})
	if !errors.As(err, &invalid) || !reflect.DeepEqual(invalid.Messages, []string{"Email Invalid email", "Phone number should be in e164 format"}) {
		t.Fatalf("formato: %v", err)
	}

	// e-mail de outra conta não conflita
	other := f.Account()
	f.Contact(other, func(c *factory.Contact) { c.Email = "livre@x.com" })
	if _, err := contacts.Update(ctx, account.ID, ct.ID, models.ContactUpdate{Email: strp("livre@x.com")}); err != nil {
		t.Fatalf("e-mail de outra conta: %v", err)
	}
	if _, err := contacts.Update(ctx, other.ID, ct.ID, models.ContactUpdate{Name: strp("x")}); !errors.Is(err, models.ErrNotFound) {
		t.Fatalf("contato de outra conta: %v", err)
	}
}

func TestContactDeleteCascades(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	account := f.Account()
	agent := f.User(account)
	inbox := f.TelegramInbox(account)
	ct := f.Contact(account)
	keep := f.Contact(account)
	f.ContactInbox(ct, inbox, "123")
	f.ContactLabel(ct, "vip")
	conv := f.Conversation(account, inbox, ct)
	f.Label(conv, "vip")
	msg := f.Message(conv)
	f.Note(ct, agent, "nota", nil)
	keptConv := f.Conversation(account, inbox, keep)
	f.Message(keptConv)
	f.Note(keep, agent, "fica", nil)
	mustExec(t, pool, `INSERT INTO attachments (message_id, account_id, file_type, created_at, updated_at) VALUES ($1, $2, 0, now(), now())`, msg.ID, account.ID)
	mustExec(t, pool, `INSERT INTO mentions (user_id, conversation_id, account_id, mentioned_at, created_at, updated_at) VALUES ($1, $2, $3, now(), now(), now())`, agent.ID, conv.ID, account.ID)
	mustExec(t, pool, `INSERT INTO conversation_participants (account_id, user_id, conversation_id, created_at, updated_at) VALUES ($1, $2, $3, now(), now())`, account.ID, agent.ID, conv.ID)
	mustExec(t, pool, `INSERT INTO notifications (account_id, user_id, notification_type, primary_actor_type, primary_actor_id, created_at, updated_at) VALUES ($1, $2, 1, 'Conversation', $3, now(), now())`, account.ID, agent.ID, conv.ID)
	mustExec(t, pool, `INSERT INTO csat_survey_responses (account_id, conversation_id, message_id, rating, contact_id, created_at, updated_at) VALUES ($1, $2, $3, 5, $4, now(), now())`, account.ID, conv.ID, msg.ID, ct.ID)

	contacts := models.NewContacts(pool)
	if err := contacts.Delete(ctx, f.Account().ID, ct.ID); !errors.Is(err, models.ErrNotFound) {
		t.Fatalf("outra conta: %v", err)
	}
	if err := contacts.Delete(ctx, account.ID, ct.ID); err != nil {
		t.Fatal(err)
	}

	for table, where := range map[string]string{
		"contacts":                  "id = $1",
		"contact_inboxes":           "contact_id = $1",
		"notes":                     "contact_id = $1",
		"conversations":             "contact_id = $1",
		"messages":                  "conversation_id = (SELECT 0) OR id = $2",
		"attachments":               "message_id = $2",
		"mentions":                  "conversation_id = $3",
		"conversation_participants": "conversation_id = $3",
		"notifications":             "primary_actor_type = 'Conversation' AND primary_actor_id = $3",
		"csat_survey_responses":     "contact_id = $1",
		"taggings":                  "(taggable_type = 'Contact' AND taggable_id = $1) OR (taggable_type = 'Conversation' AND taggable_id = $3)",
	} {
		var n int
		if err := pool.QueryRow(ctx, `SELECT count(*) FROM `+table+` WHERE `+where+` AND $1::int IS NOT NULL AND $2::int IS NOT NULL AND $3::int IS NOT NULL`,
			ct.ID, msg.ID, conv.ID).Scan(&n); err != nil {
			t.Fatalf("%s: %v", table, err)
		}
		if n != 0 {
			t.Errorf("%s: sobraram %d linhas", table, n)
		}
	}
	var kept int
	if err := pool.QueryRow(ctx, `SELECT (SELECT count(*) FROM contacts WHERE id = $1) + (SELECT count(*) FROM conversations WHERE id = $2)
		+ (SELECT count(*) FROM messages WHERE conversation_id = $2) + (SELECT count(*) FROM notes WHERE contact_id = $1)`, keep.ID, keptConv.ID).Scan(&kept); err != nil || kept != 4 {
		t.Fatalf("dados de outro contato: %d (%v)", kept, err)
	}
}

func TestContactLabelsReplaceLikeActsAsTaggableOn(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	account := f.Account()
	ct := f.Contact(account)
	f.ContactLabel(ct, "antiga")
	contacts := models.NewContacts(pool)

	got, err := contacts.SetLabels(ctx, account.ID, ct.ID, []string{" vip ", "cobranca", "VIP", ""})
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, []string{"vip", "cobranca"}) {
		t.Fatalf("label_list: %v", got)
	}
	listed, err := contacts.Labels(ctx, account.ID, ct.ID)
	if err != nil || !reflect.DeepEqual(listed, []string{"vip", "cobranca"}) {
		t.Fatalf("index: %v (%v)", listed, err)
	}
	// a tag existente é reaproveitada sem distinguir maiúsculas (strict_case_match = false)
	if _, err := contacts.SetLabels(ctx, account.ID, ct.ID, []string{"ANTIGA"}); err != nil {
		t.Fatal(err)
	}
	listed, _ = contacts.Labels(ctx, account.ID, ct.ID)
	if !reflect.DeepEqual(listed, []string{"antiga"}) {
		t.Fatalf("tag reaproveitada: %v", listed)
	}
	if _, err := contacts.Labels(ctx, f.Account().ID, ct.ID); !errors.Is(err, models.ErrNotFound) {
		t.Fatalf("outra conta: %v", err)
	}
}
