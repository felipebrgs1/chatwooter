package router_test

import (
	"context"
	"net/http"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func TestTogglePriority(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	path := "/" + itoa(conv.DisplayID)

	if code, body := s.post(path+"/toggle_priority", `{"priority":"high"}`); code != http.StatusOK {
		t.Fatalf("status = %d: %v", code, body)
	}
	if _, body := s.get(path); body["priority"] != "high" {
		t.Errorf("priority = %v", body["priority"])
	}

	// sem prioridade (a opção "None" do painel) volta a nulo: priority.presence
	if code, _ := s.post(path+"/toggle_priority", `{"priority":null}`); code != http.StatusOK {
		t.Fatalf("limpar = %d", code)
	}
	if _, body := s.get(path); body["priority"] != nil {
		t.Errorf("priority = %v, quero nulo", body["priority"])
	}

	if code, _ := s.post(path+"/toggle_priority", `{"priority":"altíssima"}`); code != http.StatusUnprocessableEntity {
		t.Errorf("prioridade inválida = %d", code)
	}
}

func TestConversationLabels(t *testing.T) {
	s := newScene(t)
	conv := s.conv()
	s.f.Label(conv, "vip")
	path := "/" + itoa(conv.DisplayID) + "/labels"

	code, body := s.get(path)
	if code != http.StatusOK || len(body["payload"].([]any)) != 1 || body["payload"].([]any)[0] != "vip" {
		t.Fatalf("index = %d: %v", code, body)
	}

	code, body = s.post(path, `{"labels":["vip","billing"]}`)
	labels := body["payload"].([]any)
	if code != http.StatusOK || len(labels) != 2 || labels[1] != "billing" {
		t.Fatalf("create = %d: %v", code, body)
	}

	// a lista de conversas filtra por etiqueta e o card mostra o cached_label_list
	_, list := s.get("?label=billing&assignee_type=all")
	payload := list["data"].(map[string]any)["payload"].([]any)
	if len(payload) != 1 {
		t.Fatalf("lista por etiqueta = %v", payload)
	}
	if got := payload[0].(map[string]any)["labels"].([]any); len(got) != 2 || got[0] != "vip" || got[1] != "billing" {
		t.Errorf("labels do card = %v", got)
	}

	_, body = s.post(path, `{"labels":[]}`)
	if len(body["payload"].([]any)) != 0 {
		t.Errorf("remover todas = %v", body)
	}
	var cached string
	if err := s.f.Pool().QueryRow(context.Background(), `SELECT COALESCE(cached_label_list, '') FROM conversations WHERE id = $1`, conv.ID).Scan(&cached); err != nil {
		t.Fatal(err)
	}
	if cached != "" {
		t.Errorf("cached_label_list = %q", cached)
	}
}

// set_team: team_id que não é positivo (o "None" do painel manda 0) tira o time.
func TestAssignTeamZeroUnassigns(t *testing.T) {
	s := newScene(t)
	team := s.f.Team(s.account)
	conv := s.conv(func(c *factory.Conversation) { c.TeamID = &team.ID })
	code, _ := s.post("/"+itoa(conv.DisplayID)+"/assignments", `{"team_id":0}`)
	if code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if _, body := s.get("/" + itoa(conv.DisplayID)); body["meta"].(map[string]any)["team"] != nil {
		t.Errorf("time continua: %v", body["meta"])
	}
}
