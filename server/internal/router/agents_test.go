package router_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func TestAgentsIndexListsAccountUsersByName(t *testing.T) {
	s := newScene(t)
	s.f.User(s.account, func(u *factory.User) { u.Name = "bruna Lima" })
	s.f.User(s.account, func(u *factory.User) { u.Name = "Ana Souza" })
	s.f.User(s.f.Account(), func(u *factory.User) { u.Name = "Aaron de outra conta" })

	rec := s.do(req{method: "GET", path: fmt.Sprintf("/api/v1/accounts/%d/agents", s.account.ID), cookie: s.cookie})
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body)
	}
	var agents []map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &agents); err != nil {
		t.Fatal(err)
	}
	names := []string{}
	for _, a := range agents {
		names = append(names, a["name"].(string))
	}
	// lower(name): "agente…" (o admin) vem antes de "ana…"
	want := []string{s.admin.Name, "Ana Souza", "bruna Lima"}
	if fmt.Sprint(names) != fmt.Sprint(want) {
		t.Fatalf("nomes = %v, quero %v", names, want)
	}
	first := agents[1]
	if first["account_id"] != float64(s.account.ID) || first["role"] != "agent" || first["available_name"] != "Ana Souza" {
		t.Errorf("agente = %v", first)
	}
}
