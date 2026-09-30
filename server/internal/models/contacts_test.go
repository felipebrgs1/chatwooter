package models_test

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func names(cs []models.Contact) []string {
	out := make([]string, 0, len(cs))
	for _, c := range cs {
		out = append(out, c.Name)
	}
	return out
}

func equal(a, b []string) bool {
	return fmt.Sprint(a) == fmt.Sprint(b)
}

func TestContactsListOnlyResolvedContactsOfTheAccount(t *testing.T) {
	pool, f := migratedPool(t)
	account, other := f.Account(), f.Account()
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Email = "com email", "a@x.com" })
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Email, c.Phone = "com telefone", "", "+5511999" })
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Email, c.Identifier = "com identifier", "", "ext-1" })
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Email = "anônimo", "" })
	f.Contact(other, func(c *factory.Contact) { c.Name = "alheio" })

	page, err := models.NewContacts(pool).List(context.Background(), account.ID, models.ContactQuery{Sort: "name"})
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"com email", "com identifier", "com telefone"}; !equal(names(page.Contacts), want) || page.Count != 3 {
		t.Fatalf("contatos = %v (count %d), want %v", names(page.Contacts), page.Count, want)
	}
}

func TestContactsListPaginatesFifteenPerPage(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	for i := range 17 {
		f.Contact(account, func(c *factory.Contact) { c.Name = fmt.Sprintf("c%02d", i) })
	}
	contacts := models.NewContacts(pool)

	first, err := contacts.List(context.Background(), account.ID, models.ContactQuery{Sort: "name", Page: 1})
	if err != nil {
		t.Fatal(err)
	}
	second, err := contacts.List(context.Background(), account.ID, models.ContactQuery{Sort: "name", Page: 2})
	if err != nil {
		t.Fatal(err)
	}
	if len(first.Contacts) != 15 || len(second.Contacts) != 2 || first.Count != 17 || second.Contacts[0].Name != "c15" {
		t.Fatalf("páginas: %d + %d (count %d), 2ª começa em %v", len(first.Contacts), len(second.Contacts), first.Count, names(second.Contacts))
	}
}

func TestContactsListSortsLikeTheSiftScopes(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	old, recent := time.Now().Add(-48*time.Hour), time.Now().Add(-time.Hour)
	f.Contact(account, func(c *factory.Contact) {
		c.Name, c.LastActivityAt, c.AdditionalAttributes = "Bruno", &old, `{"company_name": "Zeta", "city": "Recife"}`
	})
	f.Contact(account, func(c *factory.Contact) {
		c.Name, c.AdditionalAttributes = "ana", `{"company_name": "Acme", "city": "Belém"}`
	})
	f.Contact(account, func(c *factory.Contact) { c.Name, c.LastActivityAt = "Carla", &recent })
	contacts := models.NewContacts(pool)

	for sort, want := range map[string][]string{
		"name":              {"ana", "Bruno", "Carla"},
		"-name":             {"Carla", "Bruno", "ana"},
		"-last_activity_at": {"Carla", "Bruno", "ana"}, // NULLS LAST
		"last_activity_at":  {"Bruno", "Carla", "ana"},
		"company_name":      {"ana", "Bruno", "Carla"},
		"-company_name":     {"Bruno", "ana", "Carla"},
		"city":              {"ana", "Bruno", "Carla"},
	} {
		page, err := contacts.List(context.Background(), account.ID, models.ContactQuery{Sort: sort})
		if err != nil {
			t.Fatal(err)
		}
		if got := names(page.Contacts); !equal(got, want) {
			t.Errorf("sort=%s: %v, want %v", sort, got, want)
		}
	}
}

func TestContactsListFiltersByAnyLabel(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	vip := f.Contact(account, func(c *factory.Contact) { c.Name = "vip" })
	lead := f.Contact(account, func(c *factory.Contact) { c.Name = "lead" })
	f.Contact(account, func(c *factory.Contact) { c.Name = "sem etiqueta" })
	f.ContactLabel(vip, "vip")
	f.ContactLabel(lead, "lead")

	page, err := models.NewContacts(pool).List(context.Background(), account.ID,
		models.ContactQuery{Sort: "name", Labels: []string{"VIP", "lead"}})
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"lead", "vip"}; !equal(names(page.Contacts), want) || page.Count != 2 {
		t.Fatalf("com etiqueta: %v (count %d), want %v", names(page.Contacts), page.Count, want)
	}
}

func TestContactsListLoadsContactInboxes(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	contact := f.Contact(account)
	tg := f.TelegramInbox(account, func(i *factory.Inbox) { i.Name = "Bot" })
	wa := f.WhatsappInbox(account, func(i *factory.Inbox) { i.Name = "Zap" })
	f.ContactInbox(contact, tg, "123456")
	f.ContactInbox(contact, wa, "5511999")

	contacts := models.NewContacts(pool)
	page, err := contacts.List(context.Background(), account.ID, models.ContactQuery{WithInboxes: true})
	if err != nil {
		t.Fatal(err)
	}
	cis := page.Contacts[0].ContactInboxes
	if cis == nil || len(*cis) != 2 {
		t.Fatalf("contact_inboxes: %+v", cis)
	}
	first, second := (*cis)[0], (*cis)[1]
	if first.SourceID != "123456" || first.Inbox.Name != "Bot" || first.Inbox.ChannelType != "Channel::Telegram" || first.Inbox.Provider != nil {
		t.Fatalf("telegram: %+v", first)
	}
	if second.Inbox.Provider == nil || *second.Inbox.Provider != "whatsapp_cloud" {
		t.Fatalf("whatsapp: %+v", second)
	}

	without, err := contacts.List(context.Background(), account.ID, models.ContactQuery{})
	if err != nil {
		t.Fatal(err)
	}
	if without.Contacts[0].ContactInboxes != nil {
		t.Fatal("sem WithInboxes não carrega contact_inboxes")
	}
}

func TestContactsSearchMatchesNameEmailPhoneAndIdentifier(t *testing.T) {
	pool, f := migratedPool(t)
	account, other := f.Account(), f.Account()
	f.Contact(account, func(c *factory.Contact) { c.Name = "Maria Souza" })
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Email = "por email", "SOUZA@x.com" })
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Phone = "por telefone", "+55souza" })
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Identifier = "por identifier", "id-souza" })
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Identifier = "identifier é LIKE", "ID-SOUZA-2" })
	f.Contact(account, func(c *factory.Contact) { c.Name, c.Email = "João", "joao@x.com" })
	f.Contact(other, func(c *factory.Contact) { c.Name = "Outra Souza" })

	page, err := models.NewContacts(pool).Search(context.Background(), account.ID, " souza ", models.ContactQuery{Sort: "name"})
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"Maria Souza", "por email", "por identifier", "por telefone"}; !equal(names(page.Contacts), want) {
		t.Fatalf("busca: %v, want %v", names(page.Contacts), want)
	}
	if page.Count != 4 || page.HasMore {
		t.Fatalf("meta: count %d has_more %v", page.Count, page.HasMore)
	}
}

func TestContactsSearchIncludesUnresolvedAndReportsHasMore(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	for i := range 16 {
		f.Contact(account, func(c *factory.Contact) { c.Name, c.Email = fmt.Sprintf("Ana %02d", i), "" })
	}
	contacts := models.NewContacts(pool)

	page, err := contacts.Search(context.Background(), account.ID, "ana", models.ContactQuery{Sort: "name"})
	if err != nil {
		t.Fatal(err)
	}
	if len(page.Contacts) != 15 || !page.HasMore || page.Count != 15 {
		t.Fatalf("1ª página: %d contatos, has_more %v, count %d", len(page.Contacts), page.HasMore, page.Count)
	}
	last, err := contacts.Search(context.Background(), account.ID, "ana", models.ContactQuery{Sort: "name", Page: 2})
	if err != nil {
		t.Fatal(err)
	}
	if len(last.Contacts) != 1 || last.HasMore {
		t.Fatalf("2ª página: %d contatos, has_more %v", len(last.Contacts), last.HasMore)
	}
}

func TestContactsGetIsScopedToTheAccount(t *testing.T) {
	pool, f := migratedPool(t)
	account, other := f.Account(), f.Account()
	mine := f.Contact(account, func(c *factory.Contact) { c.Name = "meu"; c.AdditionalAttributes = `{"city": "Recife"}` })
	theirs := f.Contact(other)
	contacts := models.NewContacts(pool)

	got, err := contacts.Get(context.Background(), account.ID, mine.ID, true)
	if err != nil {
		t.Fatal(err)
	}
	if got.Name != "meu" || string(got.AdditionalAttributes) != `{"city": "Recife"}` || got.ContactInboxes == nil {
		t.Fatalf("contato: %+v", got)
	}
	if _, err := contacts.Get(context.Background(), account.ID, theirs.ID, true); !errors.Is(err, models.ErrNotFound) {
		t.Fatalf("contato de outra conta: err = %v, want ErrNotFound", err)
	}
}
