package models_test

import (
	"context"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestInboxesListAllForAdminsOrderedByName(t *testing.T) {
	pool, f := migratedPool(t)
	account, other := f.Account(), f.Account()
	bot := "suporte_bot"
	f.TelegramInbox(account, func(i *factory.Inbox) { i.Name, i.BotName = "suporte", &bot })
	wa := f.WhatsappInbox(account, func(i *factory.Inbox) { i.Name, i.Phone = "Vendas", "+5511999990000" })
	f.TelegramInbox(other)
	f.WorkingHour(wa, 2, 9, 18)
	f.WorkingHour(wa, 1, 8, 17)

	inboxes, err := models.NewInboxes(pool).List(context.Background(), account.ID, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(inboxes) != 2 || inboxes[0].Name != "suporte" || inboxes[1].Name != "Vendas" {
		t.Fatalf("esperava [suporte Vendas] por lower(name), veio %+v", inboxes)
	}
	tg, w := inboxes[0], inboxes[1]
	if tg.ChannelType != "Channel::Telegram" || tg.BotName == nil || *tg.BotName != bot || tg.PhoneNumber != nil {
		t.Fatalf("telegram: %+v", tg)
	}
	if w.ChannelType != "Channel::Whatsapp" || w.PhoneNumber == nil || *w.PhoneNumber != "+5511999990000" ||
		w.Provider == nil || *w.Provider != "whatsapp_cloud" {
		t.Fatalf("whatsapp: %+v", w)
	}
	if len(w.WorkingHours) != 2 || w.WorkingHours[0].DayOfWeek != 1 || w.WorkingHours[1].OpenHour == nil || *w.WorkingHours[1].OpenHour != 9 {
		t.Fatalf("working_hours por dia: %+v", w.WorkingHours)
	}
	if tg.Timezone != "UTC" || !tg.EnableAutoAssignment || tg.SenderNameType != "friendly" {
		t.Fatalf("padrões da inbox: %+v", tg)
	}
}

func TestInboxesListOnlyMemberInboxesForAgents(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	agent := f.User(account)
	mine := f.TelegramInbox(account, func(i *factory.Inbox) { i.Name = "minha" })
	f.TelegramInbox(account, func(i *factory.Inbox) { i.Name = "alheia" })
	f.InboxMember(mine, agent)

	inboxes, err := models.NewInboxes(pool).List(context.Background(), account.ID, &agent.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(inboxes) != 1 || inboxes[0].ID != mine.ID {
		t.Fatalf("agente só vê as inboxes de que é membro: %+v", inboxes)
	}
}
