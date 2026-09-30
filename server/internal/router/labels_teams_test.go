package router_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func (s scene) getJSON(path string, out any) int {
	s.t.Helper()
	rec := s.do(req{method: "GET", path: fmt.Sprintf("/api/v1/accounts/%d%s", s.account.ID, path), cookie: s.cookie})
	_ = json.Unmarshal(rec.Body.Bytes(), out)
	return rec.Code
}

func TestLabelsIndexReturnsChatwootPayload(t *testing.T) {
	s := newScene(t)
	s.f.AccountLabel(s.account, func(l *factory.AccountLabel) { l.Title, l.Color = "vip", "#00ff00" })

	var body map[string][]map[string]any
	if code := s.getJSON("/labels", &body); code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	payload := body["payload"]
	if len(payload) != 1 {
		t.Fatalf("payload: %+v", body)
	}
	got := payload[0]
	if got["title"] != "vip" || got["color"] != "#00ff00" || got["show_on_sidebar"] != true || got["description"] != nil {
		t.Fatalf("etiqueta: %+v", got)
	}
	if _, ok := got["id"]; !ok {
		t.Fatalf("sem id: %+v", got)
	}
}

func TestTeamsIndexReturnsArrayWithMembership(t *testing.T) {
	s := newScene(t)
	team := s.f.Team(s.account, func(tm *factory.Team) { tm.Name = "vendas" })
	s.f.TeamMember(team, s.admin)

	var body []map[string]any
	if code := s.getJSON("/teams", &body); code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	if len(body) != 1 {
		t.Fatalf("times: %+v", body)
	}
	got := body[0]
	want := map[string]any{
		"id": float64(team.ID), "name": "vendas", "description": nil, "allow_auto_assign": true,
		"icon": "", "icon_color": "", "account_id": float64(s.account.ID), "is_member": true,
	}
	for k, v := range want {
		if got[k] != v {
			t.Fatalf("%s: esperava %v, veio %v (%+v)", k, v, got[k], got)
		}
	}
}
