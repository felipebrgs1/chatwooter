package router_test

import (
	"fmt"
	"net/http"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func (s scene) bulk(cookie, body string) int {
	s.t.Helper()
	rec := s.do(req{method: "POST", path: fmt.Sprintf("/api/v1/accounts/%d/bulk_actions", s.account.ID), cookie: cookie, body: body})
	return rec.Code
}

func labelsOf(s scene, displayID int32) []any {
	s.t.Helper()
	_, body := s.get("/" + itoa(displayID) + "/labels")
	return body["payload"].([]any)
}

// BulkActionsJob: tira as etiquetas pedidas, põe as novas e atualiza status, agente e time de cada conversa.
func TestBulkActionsUpdatesConversations(t *testing.T) {
	s := newScene(t)
	agent := s.f.User(s.account)
	team := s.f.Team(s.account)
	first := s.conv()
	s.f.Label(first, "vip")
	second := s.conv()

	code := s.bulk(s.cookie, fmt.Sprintf(`{"type":"Conversation","ids":[%d,%d],
		"fields":{"status":"resolved","assignee_id":%d,"team_id":%d},"labels":{"add":["billing"],"remove":["vip"]}}`,
		first.DisplayID, second.DisplayID, agent.ID, team.ID))
	if code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	for _, conv := range []factory.Conversation{first, second} {
		_, body := s.get("/" + itoa(conv.DisplayID))
		meta := body["meta"].(map[string]any)
		assignee, _ := meta["assignee"].(map[string]any)
		teamJSON, _ := meta["team"].(map[string]any)
		if body["status"] != "resolved" || assignee == nil || assignee["id"] != float64(agent.ID) ||
			teamJSON == nil || teamJSON["id"] != float64(team.ID) {
			t.Errorf("conversa %d = status %v, meta %v", conv.DisplayID, body["status"], meta)
		}
		if got := labelsOf(s, conv.DisplayID); len(got) != 1 || got[0] != "billing" {
			t.Errorf("etiquetas de %d = %v", conv.DisplayID, got)
		}
	}

	// assignee_id nulo desatribui; o "None" do time manda 0
	if code := s.bulk(s.cookie, fmt.Sprintf(`{"type":"Conversation","ids":[%d],"fields":{"assignee_id":null,"team_id":0}}`,
		first.DisplayID)); code != http.StatusOK {
		t.Fatalf("desatribuir = %d", code)
	}
	_, body := s.get("/" + itoa(first.DisplayID))
	meta := body["meta"].(map[string]any)
	if meta["assignee"] != nil || meta["team"] != nil || body["status"] != "resolved" {
		t.Errorf("depois de desatribuir: status %v, meta %v", body["status"], meta)
	}
}

// PermissionFilterService: o agente só altera conversas das inboxes dele; ids de outra conta não existem.
func TestBulkActionsRespectsInboxAccess(t *testing.T) {
	s := newScene(t)
	agent := s.f.User(s.account)
	s.f.InboxMember(s.inbox, agent)
	mine := s.conv()
	otherInbox := s.f.WhatsappInbox(s.account)
	hidden := s.f.Conversation(s.account, otherInbox, s.contact)
	cookie := sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value

	if code := s.bulk(cookie, fmt.Sprintf(`{"type":"Conversation","ids":[%d,%d],"fields":{"status":"pending"}}`,
		mine.DisplayID, hidden.DisplayID)); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if _, body := s.get("/" + itoa(mine.DisplayID)); body["status"] != "pending" {
		t.Errorf("conversa da inbox do agente = %v", body["status"])
	}
	if _, body := s.get("/" + itoa(hidden.DisplayID)); body["status"] != "open" {
		t.Errorf("conversa fora das inboxes do agente mudou: %v", body["status"])
	}
}

func TestBulkActionsRejectsUnknownType(t *testing.T) {
	s := newScene(t)
	if code := s.bulk(s.cookie, `{"type":"Banana","ids":[1]}`); code != http.StatusUnprocessableEntity {
		t.Errorf("tipo desconhecido = %d", code)
	}
}
