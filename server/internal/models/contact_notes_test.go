package models_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestContactNotesCRUD(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	account := f.Account()
	agent := f.User(account)
	ct := f.Contact(account)
	old := time.Now().Add(-time.Hour)
	f.Note(ct, agent, "antiga", &old)
	notes := models.NewContactNotes(pool)

	created, err := notes.Create(ctx, account.ID, ct.ID, agent.ID, "nova")
	if err != nil {
		t.Fatal(err)
	}
	if created.Content != "nova" || created.User == nil || created.User.ID != agent.ID || created.ContactID != ct.ID {
		t.Fatalf("criada: %+v", created)
	}
	var invalid *models.ValidationError
	if _, err := notes.Create(ctx, account.ID, ct.ID, agent.ID, "  "); !errors.As(err, &invalid) || invalid.Error() != "Content can't be blank" {
		t.Fatalf("conteúdo vazio: %v", err)
	}

	list, err := notes.List(ctx, account.ID, ct.ID)
	if err != nil || len(list) != 2 || list[0].Content != "nova" || list[1].Content != "antiga" {
		t.Fatalf("latest primeiro: %+v (%v)", list, err)
	}

	updated, err := notes.Update(ctx, account.ID, ct.ID, created.ID, agent.ID, "editada")
	if err != nil || updated.Content != "editada" {
		t.Fatalf("update: %+v (%v)", updated, err)
	}
	if err := notes.Delete(ctx, account.ID, ct.ID, created.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := notes.Get(ctx, account.ID, ct.ID, created.ID); !errors.Is(err, models.ErrNotFound) {
		t.Fatalf("apagada: %v", err)
	}
	if _, err := notes.List(ctx, f.Account().ID, ct.ID); !errors.Is(err, models.ErrNotFound) {
		t.Fatalf("contato de outra conta: %v", err)
	}
}
