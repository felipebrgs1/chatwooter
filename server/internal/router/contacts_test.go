package router_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func (s scene) getContacts(path string) (int, map[string]any) {
	s.t.Helper()
	rec := s.do(req{method: "GET", path: fmt.Sprintf("/api/v1/accounts/%d/contacts%s", s.account.ID, path), cookie: s.cookie})
	var body map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	return rec.Code, body
}

func payloadList(t *testing.T, body map[string]any) []map[string]any {
	t.Helper()
	raw, _ := body["payload"].([]any)
	out := make([]map[string]any, 0, len(raw))
	for _, r := range raw {
		out = append(out, r.(map[string]any))
	}
	return out
}

func TestContactsIndexReturnsChatwootShape(t *testing.T) {
	s := newScene(t)
	seen := time.Now().Add(-time.Hour).UTC().Truncate(time.Second)
	c := s.f.Contact(s.account, func(c *factory.Contact) {
		c.Name, c.Email, c.Phone, c.LastActivityAt = "Maria", "maria@x.com", "+5511999", &seen
		c.AdditionalAttributes = `{"city": "Recife"}`
	})
	s.f.ContactInbox(c, s.inbox, "123")

	code, body := s.getContacts("?sort=-last_activity_at&page=1")
	if code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	meta := body["meta"].(map[string]any)
	// current_page ecoa o param (params[:page] || 1), como o jbuilder
	if meta["count"] != float64(2) || meta["current_page"] != "1" {
		t.Fatalf("meta: %+v", meta)
	}
	var got map[string]any
	for _, ct := range payloadList(t, body) {
		if ct["name"] == "Maria" {
			got = ct
		}
	}
	if got == nil {
		t.Fatalf("Maria fora do payload: %+v", body)
	}
	want := map[string]any{
		"id": float64(c.ID), "email": "maria@x.com", "phone_number": "+5511999", "identifier": nil, "blocked": false,
		"thumbnail": "", "availability_status": "offline", "last_activity_at": float64(seen.Unix()),
	}
	for k, v := range want {
		if got[k] != v {
			t.Errorf("%s = %v, want %v", k, got[k], v)
		}
	}
	if attrs, _ := got["additional_attributes"].(map[string]any); attrs["city"] != "Recife" {
		t.Errorf("additional_attributes: %+v", got["additional_attributes"])
	}
	if _, ok := got["custom_attributes"].(map[string]any); !ok {
		t.Errorf("custom_attributes deve ser objeto: %+v", got["custom_attributes"])
	}
	if _, ok := got["created_at"].(float64); !ok {
		t.Errorf("created_at em epoch: %+v", got["created_at"])
	}
	if _, ok := got["company_id"]; ok {
		t.Error("company_id só sai com a feature companies")
	}
	cis, _ := got["contact_inboxes"].([]any)
	if len(cis) != 1 {
		t.Fatalf("contact_inboxes: %+v", got["contact_inboxes"])
	}
	ci := cis[0].(map[string]any)
	inbox := ci["inbox"].(map[string]any)
	if ci["source_id"] != "123" || inbox["id"] != float64(s.inbox.ID) || inbox["channel_type"] != "Channel::Telegram" ||
		inbox["name"] != s.inbox.Name || inbox["avatar_url"] != "" {
		t.Fatalf("contact_inbox: %+v", ci)
	}
	if _, ok := inbox["provider"]; !ok {
		t.Fatalf("inbox_slim sem provider: %+v", inbox)
	}
}

func TestContactsIndexWithoutPageAndWithoutContactInboxes(t *testing.T) {
	s := newScene(t)
	code, body := s.getContacts("?include_contact_inboxes=false")
	if code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	if meta := body["meta"].(map[string]any); meta["current_page"] != float64(1) {
		t.Fatalf("sem page, current_page = 1: %+v", meta)
	}
	for _, ct := range payloadList(t, body) {
		if _, ok := ct["contact_inboxes"]; ok {
			t.Fatalf("include_contact_inboxes=false: %+v", ct)
		}
	}
}

func TestContactsIndexFiltersByLabels(t *testing.T) {
	s := newScene(t)
	vip := s.f.Contact(s.account, func(c *factory.Contact) { c.Name = "vip" })
	s.f.ContactLabel(vip, "vip")
	_, body := s.getContacts("?labels[]=vip")
	list := payloadList(t, body)
	if len(list) != 1 || list[0]["name"] != "vip" {
		t.Fatalf("labels[]=vip: %+v", list)
	}
}

func TestContactsSearch(t *testing.T) {
	s := newScene(t)
	s.f.Contact(s.account, func(c *factory.Contact) { c.Name, c.Email = "Joana Dark", "" })

	code, body := s.getContacts("/search?q=joana&include_contact_inboxes=false")
	if code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	list := payloadList(t, body)
	meta := body["meta"].(map[string]any)
	if len(list) != 1 || list[0]["name"] != "Joana Dark" || meta["count"] != float64(1) || meta["has_more"] != false ||
		meta["current_page"] != float64(1) {
		t.Fatalf("busca: %+v", body)
	}

	code, body = s.getContacts("/search?q=")
	if code != http.StatusUnprocessableEntity || body["error"] != "Specify search string with parameter q" {
		t.Fatalf("q vazio: %d %+v", code, body)
	}
}

func TestContactsShow(t *testing.T) {
	s := newScene(t)
	other := s.f.Account()
	theirs := s.f.Contact(other)

	code, body := s.getContacts(fmt.Sprintf("/%d", s.contact.ID))
	if code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	payload := body["payload"].(map[string]any)
	if payload["id"] != float64(s.contact.ID) {
		t.Fatalf("payload: %+v", payload)
	}
	if _, ok := payload["contact_inboxes"].([]any); !ok {
		t.Fatalf("show inclui contact_inboxes por padrão: %+v", payload)
	}

	if code, _ := s.getContacts(fmt.Sprintf("/%d", theirs.ID)); code != http.StatusNotFound {
		t.Fatalf("contato de outra conta: %d", code)
	}
	if code, _ := s.getContacts("/abc"); code != http.StatusNotFound {
		t.Fatalf("id inválido: %d", code)
	}
}
