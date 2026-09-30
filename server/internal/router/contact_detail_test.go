package router_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"reflect"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func (s scene) send(method, path, body string) (int, map[string]any) {
	s.t.Helper()
	rec := s.do(req{method: method, path: fmt.Sprintf("/api/v1/accounts/%d%s", s.account.ID, path), cookie: s.cookie, body: body})
	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}

func TestContactUpdateReturnsPayloadAndRecordInvalid(t *testing.T) {
	s := newScene(t)
	s.f.Contact(s.account, func(c *factory.Contact) { c.Email = "dono@x.com" })
	ct := s.f.Contact(s.account, func(c *factory.Contact) { c.AdditionalAttributes = `{"city": "Recife"}` })

	code, body := s.send("PATCH", fmt.Sprintf("/contacts/%d", ct.ID),
		`{"name": "Nova", "blocked": true, "additional_attributes": {"company_name": "Acme"}}`)
	if code != http.StatusOK {
		t.Fatalf("status %d: %v", code, body)
	}
	payload := body["payload"].(map[string]any)
	attrs := payload["additional_attributes"].(map[string]any)
	if payload["name"] != "Nova" || payload["blocked"] != true || attrs["city"] != "Recife" || attrs["company_name"] != "Acme" {
		t.Fatalf("payload: %v", payload)
	}
	if _, ok := payload["contact_inboxes"]; !ok {
		t.Fatalf("update inclui contact_inboxes: %v", payload)
	}

	code, body = s.send("PUT", fmt.Sprintf("/contacts/%d", ct.ID), `{"email": "DONO@x.com", "phone_number": "123"}`)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("status %d", code)
	}
	if body["message"] != "Email has already been taken, Phone number should be in e164 format" ||
		!reflect.DeepEqual(body["attributes"], []any{"email", "phone_number"}) {
		t.Fatalf("RecordInvalid: %v", body)
	}

	if code, _ := s.send("PATCH", "/contacts/999999", `{"name": "x"}`); code != http.StatusNotFound {
		t.Fatalf("inexistente: %d", code)
	}
}

func TestContactDestroyIsAdministratorOnly(t *testing.T) {
	s := newScene(t)
	ct := s.f.Contact(s.account)
	agent := s.f.User(s.account)
	asAgent := s
	asAgent.cookie = sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value

	if code, body := asAgent.send("DELETE", fmt.Sprintf("/contacts/%d", ct.ID), ""); code != http.StatusUnauthorized ||
		body["error"] != "You are not authorized to do this action" {
		t.Fatalf("agente: %d %v", code, body)
	}
	if code, _ := s.send("DELETE", fmt.Sprintf("/contacts/%d", ct.ID), ""); code != http.StatusOK {
		t.Fatalf("admin: %d", code)
	}
	if code, _ := s.send("GET", fmt.Sprintf("/contacts/%d", ct.ID), ""); code != http.StatusNotFound {
		t.Fatalf("depois de apagar: %d", code)
	}
}

func TestContactConversationsLabelsAndNotes(t *testing.T) {
	s := newScene(t)
	ct := s.f.Contact(s.account)
	conv := s.f.Conversation(s.account, s.inbox, ct)
	base := fmt.Sprintf("/contacts/%d", ct.ID)

	code, body := s.send("GET", base+"/conversations", "")
	list, _ := body["payload"].([]any)
	if code != http.StatusOK || len(list) != 1 || list[0].(map[string]any)["id"] != float64(conv.DisplayID) {
		t.Fatalf("conversas: %d %v", code, body)
	}

	code, body = s.send("POST", base+"/labels", `{"labels": ["vip", "cobranca"]}`)
	if code != http.StatusOK || !reflect.DeepEqual(body["payload"], []any{"vip", "cobranca"}) {
		t.Fatalf("labels create: %d %v", code, body)
	}
	if code, body = s.send("GET", base+"/labels", ""); !reflect.DeepEqual(body["payload"], []any{"vip", "cobranca"}) {
		t.Fatalf("labels index: %d %v", code, body)
	}

	code, note := s.send("POST", base+"/notes", `{"note": {"content": "ligar amanhã"}}`)
	if code != http.StatusOK || note["content"] != "ligar amanhã" || note["contact_id"] != float64(ct.ID) {
		t.Fatalf("nota criada: %d %v", code, note)
	}
	user := note["user"].(map[string]any)
	if user["id"] != float64(s.admin.ID) || user["role"] != "administrator" {
		t.Fatalf("autor da nota: %v", user)
	}
	if _, ok := note["created_at"].(float64); !ok {
		t.Fatalf("created_at em epoch: %v", note)
	}
	noteID := int(note["id"].(float64))

	if code, body := s.send("POST", base+"/notes", `{"note": {"content": ""}}`); code != http.StatusUnprocessableEntity ||
		body["message"] != "Content can't be blank" {
		t.Fatalf("nota vazia: %d %v", code, body)
	}
	if code, body := s.send("POST", base+"/notes", `{}`); code != http.StatusUnprocessableEntity ||
		body["error"] != "param is missing or the value is empty: note" {
		t.Fatalf("sem note: %d %v", code, body)
	}

	rec := s.do(req{method: "GET", path: fmt.Sprintf("/api/v1/accounts/%d%s/notes", s.account.ID, base), cookie: s.cookie})
	var notes []map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &notes)
	if rec.Code != http.StatusOK || len(notes) != 1 {
		t.Fatalf("notas: %d %s", rec.Code, rec.Body.String())
	}

	if code, body := s.send("PATCH", fmt.Sprintf("%s/notes/%d", base, noteID), `{"note": {"content": "editada"}}`); code != http.StatusOK ||
		body["content"] != "editada" {
		t.Fatalf("editar: %d %v", code, body)
	}
	if code, _ := s.send("DELETE", fmt.Sprintf("%s/notes/%d", base, noteID), ""); code != http.StatusOK {
		t.Fatalf("apagar nota: %d", code)
	}
	if code, _ := s.send("GET", fmt.Sprintf("%s/notes/%d", base, noteID), ""); code != http.StatusNotFound {
		t.Fatalf("nota apagada: %d", code)
	}
}

// O dashboard do Chatwoot manda `{content}` na raiz; o ParamsWrapper do Rails embrulha em `note`.
func TestContactNoteAcceptsRootContentLikeParamsWrapper(t *testing.T) {
	s := newScene(t)
	ct := s.f.Contact(s.account)
	code, note := s.send("POST", fmt.Sprintf("/contacts/%d/notes", ct.ID), `{"content": "sem wrapper"}`)
	if code != http.StatusOK || note["content"] != "sem wrapper" {
		t.Fatalf("nota com content na raiz: %d %v", code, note)
	}
}
