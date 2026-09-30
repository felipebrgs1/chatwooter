package models_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestMessagesReturnsLatestPageAscendingAndPaginatesBackward(t *testing.T) {
	w := newWorld(t)
	conv := w.conv()
	var all []factory.Message
	for range 25 {
		all = append(all, w.f.Message(conv))
	}
	ctx := context.Background()

	page, err := w.convs.Messages(ctx, w.account.ID, conv.DisplayID, 0)
	if err != nil {
		t.Fatal(err)
	}
	if len(page) != 20 || page[0].ID != all[5].ID || page[19].ID != all[24].ID {
		t.Fatalf("última página: %d mensagens, %d..%d", len(page), page[0].ID, page[len(page)-1].ID)
	}
	older, err := w.convs.Messages(ctx, w.account.ID, conv.DisplayID, page[0].ID)
	if err != nil || len(older) != 5 || older[0].ID != all[0].ID || older[4].ID != all[4].ID {
		t.Fatalf("página anterior: %d mensagens (%v)", len(older), err)
	}
	if page[0].ConversationID != conv.DisplayID {
		t.Errorf("conversation_id da mensagem = %d, want display_id %d", page[0].ConversationID, conv.DisplayID)
	}
}

func TestMessagesIncludesSenderAndAttachments(t *testing.T) {
	w := newWorld(t)
	conv := w.conv()
	msg := w.f.Message(conv)
	pool := w.f.Pool()
	ctx := context.Background()
	if _, err := pool.Exec(ctx, `UPDATE messages SET sender_type = 'Contact', sender_id = $2 WHERE id = $1`, msg.ID, w.contact.ID); err != nil {
		t.Fatal(err)
	}
	var attID int32
	if err := pool.QueryRow(ctx, `INSERT INTO attachments (message_id, account_id, file_type, extension, external_url, created_at, updated_at)
		VALUES ($1, $2, 0, 'png', 'https://cdn.example/a.png', now(), now()) RETURNING id`, msg.ID, w.account.ID).Scan(&attID); err != nil {
		t.Fatal(err)
	}

	got, err := w.convs.Messages(ctx, w.account.ID, conv.DisplayID, 0)
	if err != nil || len(got) != 1 {
		t.Fatalf("Messages = %d, %v", len(got), err)
	}
	if got[0].Sender == nil || got[0].Sender.Type != "contact" || got[0].Sender.Name != w.contact.Name {
		t.Errorf("sender = %+v", got[0].Sender)
	}
	if len(got[0].Attachments) != 1 || got[0].Attachments[0].FileType != "image" || got[0].Attachments[0].DataURL != "https://cdn.example/a.png" {
		t.Errorf("attachments = %+v", got[0].Attachments)
	}
	if got[0].ContentType != "text" || got[0].Status != "sent" {
		t.Errorf("content_type/status = %q / %q", got[0].ContentType, got[0].Status)
	}
}

func TestMessagesRejectsAForeignConversation(t *testing.T) {
	w := newWorld(t)
	conv := w.conv()
	other := w.f.Account()
	if _, err := w.convs.Messages(context.Background(), other.ID, conv.DisplayID, 0); !errors.Is(err, models.ErrNotFound) {
		t.Errorf("err = %v", err)
	}
}

func TestCreateMessageByAgent(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	conv := w.conv(func(c *factory.Conversation) { c.LastActivityAt = ago(time.Hour) })
	if _, err := w.f.Pool().Exec(ctx, `UPDATE conversations SET waiting_since = now() WHERE id = $1`, conv.ID); err != nil {
		t.Fatal(err)
	}

	msg, err := w.convs.CreateMessage(ctx, w.account.ID, conv.DisplayID, models.NewMessage{
		SenderID: w.agent.ID, Content: "Oi, posso ajudar?", EchoID: "abc",
	})
	if err != nil {
		t.Fatal(err)
	}
	if msg.MessageType != 1 || msg.Status != "sent" || msg.Private || msg.EchoID != "abc" {
		t.Errorf("mensagem = %+v", msg)
	}
	if msg.Sender == nil || msg.Sender.ID != w.agent.ID || msg.Sender.Type != "user" {
		t.Errorf("sender = %+v", msg.Sender)
	}

	got, _ := w.convs.Get(ctx, w.account.ID, conv.DisplayID)
	if got.WaitingSince != nil {
		t.Error("waiting_since deveria limpar quando o agente responde")
	}
	if got.FirstReplyCreatedAt == nil {
		t.Error("first_reply_created_at deveria ser gravado na primeira resposta")
	}
	if !got.LastActivityAt.After(time.Now().UTC().Add(-time.Minute)) {
		t.Errorf("last_activity_at não avançou: %v", got.LastActivityAt)
	}
}

func TestCreatePrivateNoteDoesNotCountAsFirstReply(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	conv := w.conv()
	msg, err := w.convs.CreateMessage(ctx, w.account.ID, conv.DisplayID, models.NewMessage{SenderID: w.agent.ID, Content: "nota", Private: true})
	if err != nil || !msg.Private {
		t.Fatalf("msg = %+v, %v", msg, err)
	}
	got, _ := w.convs.Get(ctx, w.account.ID, conv.DisplayID)
	if got.FirstReplyCreatedAt != nil {
		t.Error("nota privada não é resposta")
	}
}

func TestCreateMessageRejectsEmptyAndForeignConversation(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	conv := w.conv()
	if _, err := w.convs.CreateMessage(ctx, w.account.ID, conv.DisplayID, models.NewMessage{SenderID: w.agent.ID, Content: "  "}); !errors.Is(err, models.ErrInvalid) {
		t.Errorf("vazia: err = %v", err)
	}
	other := w.f.Account()
	if _, err := w.convs.CreateMessage(ctx, other.ID, conv.DisplayID, models.NewMessage{SenderID: w.agent.ID, Content: "x"}); !errors.Is(err, models.ErrNotFound) {
		t.Errorf("conta alheia: err = %v", err)
	}
}

func TestToggleStatus(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	conv := w.conv()

	res, err := w.convs.ToggleStatus(ctx, w.account.ID, conv.DisplayID, "resolved", nil)
	if err != nil || res.Status != "resolved" {
		t.Fatalf("resolved: %+v, %v", res, err)
	}
	until := time.Now().UTC().Add(24 * time.Hour).Truncate(time.Second)
	res, err = w.convs.ToggleStatus(ctx, w.account.ID, conv.DisplayID, "snoozed", &until)
	if err != nil || res.Status != "snoozed" || res.SnoozedUntil == nil || !res.SnoozedUntil.Equal(until) {
		t.Fatalf("snoozed: %+v, %v", res, err)
	}
	res, err = w.convs.ToggleStatus(ctx, w.account.ID, conv.DisplayID, "open", nil)
	if err != nil || res.Status != "open" || res.SnoozedUntil != nil {
		t.Fatalf("open: %+v, %v (snoozed_until deve limpar)", res, err)
	}
	if _, err := w.convs.ToggleStatus(ctx, w.account.ID, conv.DisplayID, "inventado", nil); !errors.Is(err, models.ErrInvalid) {
		t.Errorf("status inválido: err = %v", err)
	}
}

func TestAssign(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	conv := w.conv()
	team := w.f.Team(w.account)

	agent, err := w.convs.AssignAgent(ctx, w.account.ID, conv.DisplayID, &w.agent.ID)
	if err != nil || agent == nil || agent.ID != w.agent.ID {
		t.Fatalf("AssignAgent = %+v, %v", agent, err)
	}
	if got, _ := w.convs.Get(ctx, w.account.ID, conv.DisplayID); got.Assignee == nil || got.Assignee.ID != w.agent.ID {
		t.Errorf("assignee = %+v", got.Assignee)
	}
	if _, err := w.convs.AssignAgent(ctx, w.account.ID, conv.DisplayID, nil); err != nil {
		t.Fatal(err)
	}
	if got, _ := w.convs.Get(ctx, w.account.ID, conv.DisplayID); got.Assignee != nil {
		t.Error("desatribuir deveria limpar o responsável")
	}

	outsider := w.f.User(w.f.Account())
	if _, err := w.convs.AssignAgent(ctx, w.account.ID, conv.DisplayID, &outsider.ID); !errors.Is(err, models.ErrInvalid) {
		t.Errorf("agente de outra conta: err = %v", err)
	}

	if _, err := w.convs.AssignTeam(ctx, w.account.ID, conv.DisplayID, &team.ID); err != nil {
		t.Fatal(err)
	}
	if got, _ := w.convs.Get(ctx, w.account.ID, conv.DisplayID); got.Team == nil || got.Team.ID != team.ID {
		t.Errorf("team = %+v", got.Team)
	}
	foreign := w.f.Team(w.f.Account())
	if _, err := w.convs.AssignTeam(ctx, w.account.ID, conv.DisplayID, &foreign.ID); !errors.Is(err, models.ErrInvalid) {
		t.Errorf("time de outra conta: err = %v", err)
	}
}

func TestMarkSeenAndUnread(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	conv := w.conv()
	w.f.Message(conv)
	w.f.Message(conv)

	if err := w.convs.MarkSeen(ctx, w.account.ID, conv.DisplayID); err != nil {
		t.Fatal(err)
	}
	got, _ := w.convs.Get(ctx, w.account.ID, conv.DisplayID)
	if got.UnreadCount != 0 || got.AgentLastSeenAt == nil {
		t.Errorf("depois de ver: unread = %d, seen = %v", got.UnreadCount, got.AgentLastSeenAt)
	}

	if err := w.convs.MarkUnread(ctx, w.account.ID, conv.DisplayID); err != nil {
		t.Fatal(err)
	}
	got, _ = w.convs.Get(ctx, w.account.ID, conv.DisplayID)
	if got.UnreadCount == 0 {
		t.Error("marcar como não lida deveria voltar a contar mensagens novas")
	}
}

func TestAgentsOnlySeeConversationsOfTheirInboxes(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	other := w.f.TelegramInbox(w.account)
	mine := w.conv()
	w.f.Conversation(w.account, other, w.contact)
	w.f.InboxMember(w.inbox, w.agent)

	items, counts, err := w.convs.List(ctx, w.account.ID, models.ConversationFilter{UserID: w.agent.ID, OnlyInboxesOfUser: w.agent.ID})
	if err != nil {
		t.Fatal(err)
	}
	if !equalIDs(ids(items), []int32{mine.DisplayID}) || counts.All != 1 {
		t.Errorf("ids = %v, all = %d, want só a da inbox de que é membro", ids(items), counts.All)
	}

	ok, err := w.convs.CanAccessInbox(ctx, w.agent.ID, w.inbox.ID)
	if err != nil || !ok {
		t.Errorf("membro: %v, %v", ok, err)
	}
	if ok, _ := w.convs.CanAccessInbox(ctx, w.agent.ID, other.ID); ok {
		t.Error("não-membro não deveria acessar")
	}
}

// O app Elixir nunca gravou sender nas mensagens recebidas; no Chatwoot o remetente de uma incoming é o contato.
func TestIncomingMessagesWithoutSenderFallBackToTheContact(t *testing.T) {
	w := newWorld(t)
	conv := w.conv()
	w.f.Message(conv) // incoming, sem sender_type/sender_id
	out := w.f.Message(conv, func(m *factory.Message) { m.Incoming = false })

	got, err := w.convs.Messages(context.Background(), w.account.ID, conv.DisplayID, 0)
	if err != nil || len(got) != 2 {
		t.Fatalf("Messages = %d, %v", len(got), err)
	}
	if got[0].Sender == nil || got[0].Sender.Type != "contact" || got[0].Sender.ID != w.contact.ID {
		t.Errorf("incoming sem sender = %+v, want o contato da conversa", got[0].Sender)
	}
	if got[1].ID != out.ID || got[1].Sender != nil {
		t.Errorf("outgoing sem sender continua sem sender (bot/sistema): %+v", got[1].Sender)
	}
}
