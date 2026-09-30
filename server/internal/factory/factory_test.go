package factory_test

import (
	"context"
	"testing"

	"golang.org/x/crypto/bcrypt"

	"github.com/felipeborgaco/chatwooter/server/internal/db"
	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/testdb"
)

func TestFactoriesBuildAConnectedGraph(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	f := factory.New(t, pool)

	account := f.Account()
	agent := f.User(account, func(u *factory.User) { u.Name = "Ana" })
	inbox := f.TelegramInbox(account)
	contact := f.Contact(account, func(c *factory.Contact) { c.Name = "Cliente" })
	conv1 := f.Conversation(account, inbox, contact)
	conv2 := f.Conversation(account, inbox, contact)
	msg := f.Message(conv1, func(m *factory.Message) { m.Content = "oi" })

	if account.ID == 0 || agent.ID == 0 || inbox.ID == 0 || contact.ID == 0 || msg.ID == 0 {
		t.Fatalf("ids não preenchidos: %+v %+v %+v %+v %+v", account, agent, inbox, contact, msg)
	}
	if agent.Name != "Ana" {
		t.Errorf("override ignorado: %q", agent.Name)
	}

	var hash string
	if err := pool.QueryRow(ctx, `SELECT encrypted_password FROM users WHERE id=$1`, agent.ID).Scan(&hash); err != nil {
		t.Fatal(err)
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(factory.DefaultPassword)) != nil {
		t.Error("senha padrão não confere com o hash gravado")
	}

	var role int
	if err := pool.QueryRow(ctx, `SELECT role FROM account_users WHERE account_id=$1 AND user_id=$2`,
		account.ID, agent.ID).Scan(&role); err != nil {
		t.Fatalf("usuário não está vinculado à conta: %v", err)
	}

	// display_id vem do trigger por conta (o "#123" visível).
	if conv1.DisplayID != 1 || conv2.DisplayID != 2 {
		t.Errorf("display_id = %d, %d; want 1, 2", conv1.DisplayID, conv2.DisplayID)
	}

	var content string
	if err := pool.QueryRow(ctx, `SELECT content FROM messages WHERE id=$1`, msg.ID).Scan(&content); err != nil || content != "oi" {
		t.Errorf("mensagem = %q, %v", content, err)
	}
}

func TestFactoriesGenerateUniqueNames(t *testing.T) {
	pool := testdb.New(t)
	if err := db.Migrate(context.Background(), pool); err != nil {
		t.Fatal(err)
	}
	f := factory.New(t, pool)
	first, second := f.Account(), f.Account()
	if first.Name == second.Name {
		t.Error("contas com o mesmo nome")
	}
}
