package models_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

type world struct {
	f       *factory.Factory
	convs   *models.Conversations
	account factory.Account
	agent   factory.User
	inbox   factory.Inbox
	contact factory.Contact
}

func newWorld(t *testing.T) world {
	t.Helper()
	pool, f := migratedPool(t)
	account := f.Account()
	return world{
		f: f, convs: models.NewConversations(pool),
		account: account, agent: f.User(account),
		inbox: f.TelegramInbox(account), contact: f.Contact(account),
	}
}

func ago(d time.Duration) *time.Time { t := time.Now().UTC().Add(-d); return &t }

func (w world) conv(opts ...func(*factory.Conversation)) factory.Conversation {
	return w.f.Conversation(w.account, w.inbox, w.contact, opts...)
}

func ids(items []models.ConversationItem) []int32 {
	out := make([]int32, len(items))
	for i, it := range items {
		out[i] = it.ID
	}
	return out
}

func equalIDs(got, want []int32) bool {
	if len(got) != len(want) {
		return false
	}
	for i := range got {
		if got[i] != want[i] {
			return false
		}
	}
	return true
}

func TestListDefaultsToOpenNewestActivityFirst(t *testing.T) {
	w := newWorld(t)
	old := w.conv(func(c *factory.Conversation) { c.LastActivityAt = ago(2 * time.Hour) })
	recent := w.conv(func(c *factory.Conversation) { c.LastActivityAt = ago(time.Minute) })
	w.conv(func(c *factory.Conversation) { c.Status = 1 })
	other := w.f.Account()
	w.f.Conversation(other, w.f.TelegramInbox(other), w.f.Contact(other))

	items, _, err := w.convs.List(context.Background(), w.account.ID, models.ConversationFilter{UserID: w.agent.ID})
	if err != nil {
		t.Fatal(err)
	}
	if !equalIDs(ids(items), []int32{recent.DisplayID, old.DisplayID}) {
		t.Errorf("ids = %v, want [%d %d]", ids(items), recent.DisplayID, old.DisplayID)
	}
}

func TestListFilters(t *testing.T) {
	w := newWorld(t)
	team := w.f.Team(w.account)
	otherInbox := w.f.TelegramInbox(w.account)
	me := w.agent.ID
	mine := w.conv(func(c *factory.Conversation) { c.AssigneeID = &me })
	unassigned := w.conv()
	inTeam := w.conv(func(c *factory.Conversation) { c.TeamID = &team.ID })
	inOther := w.f.Conversation(w.account, otherInbox, w.contact)
	resolved := w.conv(func(c *factory.Conversation) { c.Status = 1 })
	labeled := w.conv()
	w.f.Label(labeled, "Urgente")

	cases := map[string]struct {
		filter models.ConversationFilter
		want   []int32
	}{
		"status all":  {models.ConversationFilter{Status: "all"}, []int32{labeled.DisplayID, resolved.DisplayID, inOther.DisplayID, inTeam.DisplayID, unassigned.DisplayID, mine.DisplayID}},
		"resolved":    {models.ConversationFilter{Status: "resolved"}, []int32{resolved.DisplayID}},
		"mine":        {models.ConversationFilter{AssigneeType: "me"}, []int32{mine.DisplayID}},
		"assigned":    {models.ConversationFilter{AssigneeType: "assigned"}, []int32{mine.DisplayID}},
		"unassigned":  {models.ConversationFilter{AssigneeType: "unassigned"}, []int32{labeled.DisplayID, inOther.DisplayID, inTeam.DisplayID, unassigned.DisplayID}},
		"inbox":       {models.ConversationFilter{InboxID: otherInbox.ID}, []int32{inOther.DisplayID}},
		"team":        {models.ConversationFilter{TeamID: team.ID}, []int32{inTeam.DisplayID}},
		"label":       {models.ConversationFilter{Label: "urgente"}, []int32{labeled.DisplayID}},
		"unattended":  {models.ConversationFilter{ConversationType: "unattended"}, []int32{labeled.DisplayID, inOther.DisplayID, inTeam.DisplayID, unassigned.DisplayID, mine.DisplayID}},
		"mentions":    {models.ConversationFilter{ConversationType: "mention"}, nil},
		"participant": {models.ConversationFilter{ConversationType: "participating"}, nil},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			c.filter.UserID = me
			items, _, err := w.convs.List(context.Background(), w.account.ID, c.filter)
			if err != nil {
				t.Fatal(err)
			}
			// cada conversa foi criada depois da anterior: a ordem padrão é a mais nova primeiro
			if !equalIDs(ids(items), c.want) {
				t.Errorf("ids = %v, want %v", ids(items), c.want)
			}
		})
	}
}

func TestListCountsCoverTheFilteredRelationRegardlessOfAssigneeTab(t *testing.T) {
	w := newWorld(t)
	me := w.agent.ID
	other := w.f.User(w.account).ID
	w.conv(func(c *factory.Conversation) { c.AssigneeID = &me })
	w.conv(func(c *factory.Conversation) { c.AssigneeID = &other })
	w.conv()
	w.conv()
	w.conv(func(c *factory.Conversation) { c.Status = 1 })

	_, counts, err := w.convs.List(context.Background(), w.account.ID, models.ConversationFilter{UserID: me, AssigneeType: "me"})
	if err != nil {
		t.Fatal(err)
	}
	want := models.ConversationCounts{Mine: 1, Assigned: 2, Unassigned: 2, All: 4}
	if counts != want {
		t.Errorf("counts = %+v, want %+v", counts, want)
	}
}

func TestListPaginatesBy25(t *testing.T) {
	w := newWorld(t)
	for range 27 {
		w.conv()
	}
	first, _, _ := w.convs.List(context.Background(), w.account.ID, models.ConversationFilter{Page: 1})
	second, _, _ := w.convs.List(context.Background(), w.account.ID, models.ConversationFilter{Page: 2})
	if len(first) != 25 || len(second) != 2 {
		t.Errorf("páginas = %d e %d, want 25 e 2", len(first), len(second))
	}
}

func TestListSortKeys(t *testing.T) {
	w := newWorld(t)
	high, low := int32(2), int32(0)
	a := w.conv(func(c *factory.Conversation) { c.Priority = &low; c.LastActivityAt = ago(3 * time.Hour) })
	b := w.conv(func(c *factory.Conversation) { c.Priority = &high; c.LastActivityAt = ago(2 * time.Hour) })
	c := w.conv(func(c *factory.Conversation) { c.LastActivityAt = ago(time.Hour) })

	for sortBy, want := range map[string][]int32{
		"last_activity_at_desc": {c.DisplayID, b.DisplayID, a.DisplayID},
		"last_activity_at_asc":  {a.DisplayID, b.DisplayID, c.DisplayID},
		"priority_desc":         {b.DisplayID, a.DisplayID, c.DisplayID},
		"priority_asc":          {a.DisplayID, b.DisplayID, c.DisplayID},
		"created_at_asc":        {a.DisplayID, b.DisplayID, c.DisplayID},
		"created_at_desc":       {c.DisplayID, b.DisplayID, a.DisplayID},
	} {
		items, _, err := w.convs.List(context.Background(), w.account.ID, models.ConversationFilter{SortBy: sortBy})
		if err != nil || !equalIDs(ids(items), want) {
			t.Errorf("sort %s: %v (%v), want %v", sortBy, ids(items), err, want)
		}
	}
}

func TestListHydratesCardData(t *testing.T) {
	w := newWorld(t)
	me := w.agent.ID
	team := w.f.Team(w.account)
	seen := ago(time.Hour)
	conv := w.conv(func(c *factory.Conversation) {
		c.AssigneeID = &me
		c.TeamID = &team.ID
		c.AgentLastSeen = seen
	})
	w.f.Label(conv, "vip")
	w.f.Message(conv, func(m *factory.Message) { m.Content = "antiga" })
	last := w.f.Message(conv, func(m *factory.Message) { m.Content = "a última" })

	items, _, err := w.convs.List(context.Background(), w.account.ID, models.ConversationFilter{})
	if err != nil || len(items) != 1 {
		t.Fatalf("items = %d, %v", len(items), err)
	}
	it := items[0]
	if it.Contact.Name != w.contact.Name || it.Channel != "Channel::Telegram" {
		t.Errorf("contato/canal = %q / %q", it.Contact.Name, it.Channel)
	}
	if it.Assignee == nil || it.Assignee.ID != me || it.Team == nil || it.Team.ID != team.ID {
		t.Errorf("assignee/team = %+v / %+v", it.Assignee, it.Team)
	}
	if len(it.Labels) != 1 || it.Labels[0] != "vip" {
		t.Errorf("labels = %v", it.Labels)
	}
	if it.LastMessage == nil || it.LastMessage.ID != last.ID || it.LastNonActivity == nil || it.LastNonActivity.ID != last.ID {
		t.Errorf("última mensagem = %+v / %+v", it.LastMessage, it.LastNonActivity)
	}
	if it.UnreadCount != 2 {
		t.Errorf("UnreadCount = %d, want 2 (incoming depois do último visto)", it.UnreadCount)
	}
	if it.Status != "open" || it.Priority != nil {
		t.Errorf("status/priority = %q / %v", it.Status, it.Priority)
	}
}

func TestUnreadCountIsCappedAtTen(t *testing.T) {
	w := newWorld(t)
	conv := w.conv()
	for range 12 {
		w.f.Message(conv)
	}
	items, _, _ := w.convs.List(context.Background(), w.account.ID, models.ConversationFilter{})
	if items[0].UnreadCount != 10 {
		t.Errorf("UnreadCount = %d, want 10", items[0].UnreadCount)
	}
}

func TestGetIsScopedByAccountAndUsesDisplayID(t *testing.T) {
	w := newWorld(t)
	conv := w.conv()
	got, err := w.convs.Get(context.Background(), w.account.ID, conv.DisplayID)
	if err != nil || got.ID != conv.DisplayID {
		t.Fatalf("Get = %+v, %v", got, err)
	}
	other := w.f.Account()
	if _, err := w.convs.Get(context.Background(), other.ID, conv.DisplayID); !errors.Is(err, models.ErrNotFound) {
		t.Errorf("conta alheia: err = %v", err)
	}
	if _, err := w.convs.Get(context.Background(), w.account.ID, 9999); !errors.Is(err, models.ErrNotFound) {
		t.Errorf("inexistente: err = %v", err)
	}
}
