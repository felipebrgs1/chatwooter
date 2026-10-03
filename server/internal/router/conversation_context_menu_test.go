package router_test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

// conversations#destroy: só administrador (ConversationPolicy#destroy?) e leva mensagens e etiquetas junto.
func TestDeleteConversation(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	s.f.Label(conv, "vip")
	s.f.Message(conv)
	keep := s.conv()

	agent := s.f.User(s.account)
	s.f.InboxMember(s.inbox, agent)
	agentCookie := sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value
	rec := s.do(req{method: "DELETE", path: s.path("/" + itoa(conv.DisplayID)), cookie: agentCookie})
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("agente = %d, quero 401", rec.Code)
	}

	rec = s.do(req{method: "DELETE", path: s.path("/" + itoa(conv.DisplayID)), cookie: s.cookie})
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body)
	}
	if code, _ := s.get("/" + itoa(conv.DisplayID)); code != http.StatusNotFound {
		t.Errorf("depois de excluir, show = %d", code)
	}
	if code, _ := s.get("/" + itoa(keep.DisplayID)); code != http.StatusOK {
		t.Errorf("outra conversa sumiu: %d", code)
	}
	var left int
	if err := s.f.Pool().QueryRow(context.Background(), `SELECT
		(SELECT count(*) FROM messages WHERE conversation_id = $1) +
		(SELECT count(*) FROM taggings WHERE taggable_type = 'Conversation' AND taggable_id = $1)`, conv.ID).Scan(&left); err != nil {
		t.Fatal(err)
	}
	if left != 0 {
		t.Errorf("sobraram %d mensagens/etiquetas", left)
	}

	rec = s.do(req{method: "DELETE", path: s.path("/" + itoa(conv.DisplayID)), cookie: s.cookie})
	if rec.Code != http.StatusNotFound {
		t.Errorf("excluir de novo = %d", rec.Code)
	}
}

// assignable_agents: membros de todas as inboxes pedidas + administradores da conta, sem repetir.
func TestAssignableAgents(t *testing.T) {
	s := newScene(t)
	member := s.f.User(s.account, func(u *factory.User) { u.Name = "Bia Membro" })
	s.f.InboxMember(s.inbox, member)
	s.f.InboxMember(s.inbox, s.admin)
	s.f.User(s.account, func(u *factory.User) { u.Name = "Caio Fora" })

	list := func(cookie, query string) (int, []string) {
		rec := s.do(req{method: "GET", path: fmt.Sprintf("/api/v1/accounts/%d/assignable_agents%s", s.account.ID, query), cookie: cookie})
		var body struct {
			Payload []struct {
				Name string `json:"name"`
			} `json:"payload"`
		}
		_ = json.Unmarshal(rec.Body.Bytes(), &body)
		names := []string{}
		for _, a := range body.Payload {
			names = append(names, a.Name)
		}
		return rec.Code, names
	}

	code, names := list(s.cookie, fmt.Sprintf("?inbox_ids[]=%d", s.inbox.ID))
	want := []string{s.admin.Name, "Bia Membro"}
	if code != http.StatusOK || fmt.Sprint(names) != fmt.Sprint(want) {
		t.Fatalf("status %d, nomes %v, quero %v", code, names, want)
	}

	other := s.f.TelegramInbox(s.f.Account())
	if code, _ := list(s.cookie, fmt.Sprintf("?inbox_ids[]=%d", other.ID)); code != http.StatusNotFound {
		t.Errorf("inbox de outra conta = %d", code)
	}

	// InboxPolicy#show?: agente fora da inbox não consulta
	outsider := s.f.User(s.account)
	cookie := sessionCookie(s.signIn(outsider.Email, factory.DefaultPassword)).Value
	if code, _ := list(cookie, fmt.Sprintf("?inbox_ids[]=%d", s.inbox.ID)); code != http.StatusUnauthorized {
		t.Errorf("agente fora da inbox = %d", code)
	}
}
