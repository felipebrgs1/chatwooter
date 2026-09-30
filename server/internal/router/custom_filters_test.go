package router_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func (s scene) filtersPath(rest string) string {
	return fmt.Sprintf("/api/v1/accounts/%d/custom_filters%s", s.account.ID, rest)
}

func (s scene) customFilters(method, rest, body, cookie string) (int, any) {
	s.t.Helper()
	rec := s.do(req{method: method, path: s.filtersPath(rest), cookie: cookie, body: body})
	var out any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}

const folderBody = `{"custom_filter":{"name":"VIPs abertos","filter_type":"conversation","query":{"payload":[
	{"attribute_key":"status","filter_operator":"equal_to","values":["open"],"query_operator":"and"},
	{"attribute_key":"labels","filter_operator":"equal_to","values":["vip"]}]}}}`

func TestCustomFiltersCRUD(t *testing.T) {
	s := newScene(t)

	code, created := s.customFilters("POST", "", folderBody, s.cookie)
	if code != http.StatusOK {
		t.Fatalf("create = %d: %v", code, created)
	}
	folder := created.(map[string]any)
	if folder["name"] != "VIPs abertos" || folder["filter_type"] != "conversation" || folder["created_at"] == nil {
		t.Errorf("create = %v", folder)
	}
	payload := folder["query"].(map[string]any)["payload"].([]any)
	if len(payload) != 2 || payload[1].(map[string]any)["attribute_key"] != "labels" {
		t.Errorf("query = %v", folder["query"])
	}
	id := fmt.Sprint(folder["id"])

	code, list := s.customFilters("GET", "?filter_type=conversation", "", s.cookie)
	if code != http.StatusOK || len(list.([]any)) != 1 {
		t.Fatalf("index = %d: %v", code, list)
	}

	code, updated := s.customFilters("PATCH", "/"+id, `{"custom_filter":{"name":"Só VIPs","query":{"payload":[
		{"attribute_key":"labels","filter_operator":"equal_to","values":["vip"]}]}}}`, s.cookie)
	if code != http.StatusOK || updated.(map[string]any)["name"] != "Só VIPs" {
		t.Fatalf("update = %d: %v", code, updated)
	}
	if n := len(updated.(map[string]any)["query"].(map[string]any)["payload"].([]any)); n != 1 {
		t.Errorf("query atualizada com %d condições", n)
	}

	code, shown := s.customFilters("GET", "/"+id, "", s.cookie)
	if code != http.StatusOK || shown.(map[string]any)["name"] != "Só VIPs" {
		t.Fatalf("show = %d: %v", code, shown)
	}

	if code, _ := s.customFilters("DELETE", "/"+id, "", s.cookie); code != http.StatusNoContent {
		t.Fatalf("destroy = %d", code)
	}
	if code, _ := s.customFilters("GET", "/"+id, "", s.cookie); code != http.StatusNotFound {
		t.Fatalf("show depois de excluir = %d", code)
	}
}

func TestCustomFiltersAreScopedToUserAndType(t *testing.T) {
	s := newScene(t)
	_, created := s.customFilters("POST", "", folderBody, s.cookie)
	id := fmt.Sprint(created.(map[string]any)["id"])
	s.customFilters("POST", "", `{"custom_filter":{"name":"Leads","filter_type":"contact","query":{"payload":[]}}}`, s.cookie)

	// sem filter_type, o index traz as de conversa
	_, list := s.customFilters("GET", "", "", s.cookie)
	if items := list.([]any); len(items) != 1 || items[0].(map[string]any)["name"] != "VIPs abertos" {
		t.Errorf("index padrão = %v", list)
	}
	_, list = s.customFilters("GET", "?filter_type=contact", "", s.cookie)
	if items := list.([]any); len(items) != 1 || items[0].(map[string]any)["name"] != "Leads" {
		t.Errorf("index de contato = %v", list)
	}

	// as pastas são de quem criou: outro agente da conta não vê nem mexe
	agent := s.f.User(s.account)
	other := sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value
	if _, list := s.customFilters("GET", "", "", other); len(list.([]any)) != 0 {
		t.Errorf("outro usuário vê %v", list)
	}
	for _, method := range []string{"GET", "PATCH", "DELETE"} {
		if code, _ := s.customFilters(method, "/"+id, `{"custom_filter":{"name":"x"}}`, other); code != http.StatusNotFound {
			t.Errorf("%s de outro usuário = %d", method, code)
		}
	}
}

func TestCustomFiltersValidation(t *testing.T) {
	s := newScene(t)
	cases := []struct {
		name, body string
		code       int
		want       any
	}{
		{
			"sem custom_filter", `{}`, http.StatusBadRequest,
			map[string]any{"error": "param is missing or the value is empty: custom_filter"},
		},
		{
			"fuso inválido", `{"custom_filter":{"name":"x","query":{"payload":[{"attribute_key":"created_at","filter_operator":"is_less_than","values":["2024-01-01"],"timezone":"Lua/Base"}]}}}`,
			http.StatusUnprocessableEntity,
			map[string]any{"error": "Invalid value. The values provided for timezone are invalid"},
		},
		{
			"payload que não é lista", `{"custom_filter":{"name":"x","query":{"payload":"status"}}}`,
			http.StatusUnprocessableEntity,
			map[string]any{"error": "Invalid value. The values provided for payload are invalid"},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			code, body := s.customFilters("POST", "", tc.body, s.cookie)
			if code != tc.code || fmt.Sprint(body) != fmt.Sprint(tc.want) {
				t.Fatalf("status = %d, body = %v", code, body)
			}
		})
	}
}

// O dashboard manda filter_type como número (SaveCustomView.vue: filterType 0/1); o enum do Rails aceita os dois.
func TestCustomFiltersAcceptNumericFilterType(t *testing.T) {
	s := newScene(t)
	code, created := s.customFilters("POST", "", `{"custom_filter":{"name":"Leads","filter_type":1,"query":{"payload":[]}}}`, s.cookie)
	if code != http.StatusOK || created.(map[string]any)["filter_type"] != "contact" {
		t.Fatalf("create = %d: %v", code, created)
	}
}
