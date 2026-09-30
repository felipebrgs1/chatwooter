package models_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestContactConversationsVisibleToTheUser(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	account := f.Account()
	admin := f.User(account, func(u *factory.User) { u.Role = 1 })
	agent := f.User(account)
	mine, other := f.TelegramInbox(account), f.TelegramInbox(account)
	f.InboxMember(mine, agent)
	ct := f.Contact(account)
	at := func(h int) *time.Time { v := time.Now().Add(time.Duration(-h) * time.Hour); return &v }
	older := f.Conversation(account, mine, ct, func(c *factory.Conversation) { c.LastActivityAt = at(3) })
	newer := f.Conversation(account, mine, ct, func(c *factory.Conversation) { c.LastActivityAt = at(1) })
	hidden := f.Conversation(account, other, ct, func(c *factory.Conversation) { c.LastActivityAt = at(2) })
	f.Conversation(account, mine, f.Contact(account))
	convs := models.NewConversations(pool)

	all, err := convs.ForContact(ctx, account.ID, ct.ID, admin.ID, nil)
	if err != nil {
		t.Fatal(err)
	}
	if ids := displayIDs(all); len(ids) != 3 || ids[0] != newer.DisplayID || ids[1] != hidden.DisplayID || ids[2] != older.DisplayID {
		t.Fatalf("admin vê todas, por last_activity_at desc: %v", ids)
	}
	if all[0].Contact.ID != ct.ID {
		t.Fatalf("conversa hidratada: %+v", all[0])
	}

	visible, err := convs.ForContact(ctx, account.ID, ct.ID, agent.ID, &agent.ID)
	if err != nil {
		t.Fatal(err)
	}
	if ids := displayIDs(visible); len(ids) != 2 || ids[0] != newer.DisplayID || ids[1] != older.DisplayID {
		t.Fatalf("agente só das inboxes dele: %v", ids)
	}

	if _, err := convs.ForContact(ctx, f.Account().ID, ct.ID, admin.ID, nil); !errors.Is(err, models.ErrNotFound) {
		t.Fatalf("contato de outra conta: %v", err)
	}
}

func displayIDs(items []models.ConversationItem) []int32 {
	out := []int32{}
	for _, it := range items {
		out = append(out, it.ID)
	}
	return out
}
