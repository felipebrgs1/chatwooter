package router_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

type scene struct {
	*app
	account factory.Account
	admin   factory.User
	inbox   factory.Inbox
	contact factory.Contact
	cookie  string
}

func newScene(t *testing.T) scene {
	t.Helper()
	a := newApp(t)
	account := a.f.Account()
	admin := a.f.User(account, func(u *factory.User) { u.Role = 1 })
	return scene{
		app: a, account: account, admin: admin,
		inbox: a.f.TelegramInbox(account), contact: a.f.Contact(account),
		cookie: sessionCookie(a.signIn(admin.Email, factory.DefaultPassword)).Value,
	}
}

func (s scene) path(rest string) string {
	return fmt.Sprintf("/api/v1/accounts/%d/conversations%s", s.account.ID, rest)
}

func (s scene) get(rest string) (int, map[string]any) {
	s.t.Helper()
	rec := s.do(req{method: "GET", path: s.path(rest), cookie: s.cookie})
	var body map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	return rec.Code, body
}

func (s scene) post(rest, payload string) (int, map[string]any) {
	s.t.Helper()
	rec := s.do(req{method: "POST", path: s.path(rest), cookie: s.cookie, body: payload})
	var body map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	return rec.Code, body
}

func (s scene) conv(opts ...func(*factory.Conversation)) factory.Conversation {
	return s.f.Conversation(s.account, s.inbox, s.contact, opts...)
}

func TestConversationsIndexReturnsChatwootShape(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	s.f.Label(conv, "vip")
	s.f.Message(conv, func(m *factory.Message) { m.Content = "preciso de ajuda" })

	code, body := s.get("")
	if code != http.StatusOK {
		t.Fatalf("status = %d: %v", code, body)
	}
	data := body["data"].(map[string]any)
	meta := data["meta"].(map[string]any)
	if meta["all_count"] != float64(1) || meta["unassigned_count"] != float64(1) || meta["mine_count"] != float64(0) {
		t.Errorf("meta = %v", meta)
	}
	first := data["payload"].([]any)[0].(map[string]any)
	if first["id"] != float64(conv.DisplayID) || first["status"] != "open" || first["unread_count"] != float64(1) {
		t.Errorf("conversa = id %v status %v unread %v", first["id"], first["status"], first["unread_count"])
	}
	sender := first["meta"].(map[string]any)["sender"].(map[string]any)
	if sender["name"] != s.contact.Name {
		t.Errorf("meta.sender = %v", sender)
	}
	if first["meta"].(map[string]any)["channel"] != "Channel::Telegram" {
		t.Errorf("channel = %v", first["meta"])
	}
	msgs := first["messages"].([]any)
	if len(msgs) != 1 || msgs[0].(map[string]any)["content"] != "preciso de ajuda" {
		t.Errorf("messages = %v", msgs)
	}
	if labels := first["labels"].([]any); len(labels) != 1 || labels[0] != "vip" {
		t.Errorf("labels = %v", labels)
	}
	for _, key := range []string{"uuid", "inbox_id", "can_reply", "muted", "timestamp", "created_at", "last_activity_at", "waiting_since", "agent_last_seen_at", "priority", "snoozed_until", "additional_attributes", "custom_attributes", "last_non_activity_message", "first_reply_created_at", "sla_policy_id"} {
		if _, ok := first[key]; !ok {
			t.Errorf("campo %q ausente", key)
		}
	}
}

func TestConversationsIndexQueryParams(t *testing.T) {
	s := newScene(t)
	open := s.conv()
	resolved := s.conv(func(c *factory.Conversation) { c.Status = 1 })
	mine := s.conv(func(c *factory.Conversation) { id := s.admin.ID; c.AssigneeID = &id })

	idsOf := func(rest string) []float64 {
		_, body := s.get(rest)
		var out []float64
		for _, c := range body["data"].(map[string]any)["payload"].([]any) {
			out = append(out, c.(map[string]any)["id"].(float64))
		}
		return out
	}
	if got := idsOf(""); len(got) != 2 {
		t.Errorf("padrão (open) = %v", got)
	}
	if got := idsOf("?status=resolved"); len(got) != 1 || got[0] != float64(resolved.DisplayID) {
		t.Errorf("status=resolved = %v", got)
	}
	if got := idsOf("?status=all"); len(got) != 3 {
		t.Errorf("status=all = %v", got)
	}
	if got := idsOf("?assignee_type=me"); len(got) != 1 || got[0] != float64(mine.DisplayID) {
		t.Errorf("assignee_type=me = %v", got)
	}
	if got := idsOf("?assignee_type=unassigned"); len(got) != 1 || got[0] != float64(open.DisplayID) {
		t.Errorf("assignee_type=unassigned = %v", got)
	}
	if got := idsOf("?inbox_id=999"); len(got) != 0 {
		t.Errorf("inbox_id=999 = %v", got)
	}
}

func TestConversationsMetaCounts(t *testing.T) {
	s := newScene(t)
	s.conv()
	code, body := s.get("/meta")
	if code != http.StatusOK || body["meta"].(map[string]any)["all_count"] != float64(1) {
		t.Errorf("meta = %d %v", code, body)
	}
}

func TestAgentsDoNotSeeOtherInboxes(t *testing.T) {
	s := newScene(t)
	agent := s.f.User(s.account)
	s.f.InboxMember(s.inbox, agent)
	other := s.f.TelegramInbox(s.account)
	visible := s.conv()
	hidden := s.f.Conversation(s.account, other, s.contact)
	cookie := sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value

	rec := s.do(req{method: "GET", path: s.path(""), cookie: cookie})
	var body map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	payload := body["data"].(map[string]any)["payload"].([]any)
	if len(payload) != 1 || payload[0].(map[string]any)["id"] != float64(visible.DisplayID) {
		t.Errorf("agente vê %v", payload)
	}
	for _, rest := range []string{fmt.Sprintf("/%d", hidden.DisplayID), fmt.Sprintf("/%d/messages", hidden.DisplayID)} {
		if rec := s.do(req{method: "GET", path: s.path(rest), cookie: cookie}); rec.Code != http.StatusUnauthorized {
			t.Errorf("GET %s: status = %d, want 401", rest, rec.Code)
		}
	}
	rec = s.do(req{method: "POST", path: s.path(fmt.Sprintf("/%d/messages", hidden.DisplayID)), cookie: cookie, body: `{"content":"oi"}`})
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("POST mensagem em inbox alheia: %d", rec.Code)
	}
}

func TestShowConversation(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	code, body := s.get(fmt.Sprintf("/%d", conv.DisplayID))
	if code != http.StatusOK || body["id"] != float64(conv.DisplayID) {
		t.Fatalf("show = %d %v", code, body)
	}
	if code, _ := s.get("/9999"); code != http.StatusNotFound {
		t.Errorf("inexistente: %d", code)
	}
	if code, _ := s.get("/abc"); code != http.StatusNotFound {
		t.Errorf("id inválido: %d", code)
	}
	other := newScene(t)
	if rec := other.do(req{method: "GET", path: other.path(fmt.Sprintf("/%d", conv.DisplayID)), cookie: other.cookie}); rec.Code != http.StatusNotFound {
		t.Errorf("display_id de outra conta dentro da minha conta: %d, want 404", rec.Code)
	}
}

func TestListMessagesAndSend(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	for range 3 {
		s.f.Message(conv)
	}
	p := fmt.Sprintf("/%d/messages", conv.DisplayID)

	code, body := s.get(p)
	if code != http.StatusOK {
		t.Fatalf("messages = %d %v", code, body)
	}
	payload := body["payload"].([]any)
	if len(payload) != 3 {
		t.Fatalf("payload = %d mensagens", len(payload))
	}
	if body["meta"].(map[string]any)["contact"].(map[string]any)["name"] != s.contact.Name {
		t.Errorf("meta.contact = %v", body["meta"])
	}
	if first := payload[0].(map[string]any); first["conversation_id"] != float64(conv.DisplayID) || first["message_type"] != float64(0) || first["content_type"] != "text" {
		t.Errorf("mensagem = %v", first)
	}

	code, sent := s.post(p, `{"content":"Oi, tudo bem?","echo_id":"tmp-1"}`)
	if code != http.StatusOK {
		t.Fatalf("send = %d %v", code, sent)
	}
	if sent["content"] != "Oi, tudo bem?" || sent["message_type"] != float64(1) || sent["echo_id"] != "tmp-1" || sent["private"] != false {
		t.Errorf("mensagem enviada = %v", sent)
	}
	if sender := sent["sender"].(map[string]any); sender["id"] != float64(s.admin.ID) || sender["type"] != "user" {
		t.Errorf("sender = %v", sender)
	}
	if _, body := s.get(p); len(body["payload"].([]any)) != 4 {
		t.Error("a mensagem enviada deveria aparecer na lista")
	}

	if code, _ := s.post(p, `{"content":"   "}`); code != http.StatusUnprocessableEntity {
		t.Errorf("mensagem vazia: %d, want 422", code)
	}
	if code, _ := s.post(p, `{nao-json`); code != http.StatusBadRequest {
		t.Errorf("corpo inválido: %d, want 400", code)
	}
}

func TestMessagesBeforeParam(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	var msgs []factory.Message
	for range 22 {
		msgs = append(msgs, s.f.Message(conv))
	}
	_, body := s.get(fmt.Sprintf("/%d/messages?before=%d", conv.DisplayID, msgs[2].ID))
	payload := body["payload"].([]any)
	if len(payload) != 2 || payload[0].(map[string]any)["id"] != float64(msgs[0].ID) {
		t.Errorf("before = %v", payload)
	}
}

func TestToggleStatusEndpoint(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	p := fmt.Sprintf("/%d/toggle_status", conv.DisplayID)

	code, body := s.post(p, `{"status":"resolved"}`)
	payload, _ := body["payload"].(map[string]any)
	if code != http.StatusOK || payload["success"] != true || payload["current_status"] != "resolved" || payload["conversation_id"] != float64(conv.DisplayID) {
		t.Fatalf("toggle = %d %v", code, body)
	}
	until := time.Now().Add(time.Hour).Unix()
	code, body = s.post(p, fmt.Sprintf(`{"status":"snoozed","snoozed_until":%d}`, until))
	payload, _ = body["payload"].(map[string]any)
	if code != http.StatusOK || payload["current_status"] != "snoozed" || payload["snoozed_until"] == nil {
		t.Errorf("snooze = %d %v", code, body)
	}
	if code, _ := s.post(p, `{"status":"inventado"}`); code != http.StatusUnprocessableEntity {
		t.Errorf("status inválido: %d", code)
	}
}

func TestAssignmentsEndpoint(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	team := s.f.Team(s.account)
	p := fmt.Sprintf("/%d/assignments", conv.DisplayID)

	code, body := s.post(p, fmt.Sprintf(`{"assignee_id":%d}`, s.admin.ID))
	if code != http.StatusOK || body["id"] != float64(s.admin.ID) || body["role"] != "administrator" {
		t.Errorf("atribuir agente = %d %v", code, body)
	}
	code, body = s.post(p, fmt.Sprintf(`{"team_id":%d}`, team.ID))
	if code != http.StatusOK || body["id"] != float64(team.ID) || body["name"] != team.Name {
		t.Errorf("atribuir time = %d %v", code, body)
	}
	if _, show := s.get(fmt.Sprintf("/%d", conv.DisplayID)); show["meta"].(map[string]any)["assignee"].(map[string]any)["id"] != float64(s.admin.ID) {
		t.Errorf("show depois de atribuir: %v", show["meta"])
	}
	outsider := s.f.User(s.f.Account())
	if code, _ := s.post(p, fmt.Sprintf(`{"assignee_id":%d}`, outsider.ID)); code != http.StatusUnprocessableEntity {
		t.Errorf("agente de fora: %d", code)
	}
}

func TestSeenAndUnreadEndpoints(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	s.f.Message(conv)
	id := fmt.Sprintf("/%d", conv.DisplayID)

	code, body := s.post(id+"/update_last_seen", "")
	if code != http.StatusOK || body["unread_count"] != float64(0) {
		t.Errorf("update_last_seen = %d unread=%v", code, body["unread_count"])
	}
	code, body = s.post(id+"/unread", "")
	if code != http.StatusOK || body["unread_count"] != float64(1) {
		t.Errorf("unread = %d unread=%v", code, body["unread_count"])
	}
}

func TestConversationEndpointsRequireLogin(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	for _, r := range []req{
		{method: "GET", path: s.path("")},
		{method: "GET", path: s.path(fmt.Sprintf("/%d", conv.DisplayID))},
		{method: "POST", path: s.path(fmt.Sprintf("/%d/messages", conv.DisplayID)), body: `{"content":"x"}`},
	} {
		if rec := s.do(r); rec.Code != http.StatusUnauthorized {
			t.Errorf("%s %s sem login: %d", r.method, r.path, rec.Code)
		}
	}
}
