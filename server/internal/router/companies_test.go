package router_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func (s scene) companyRequest(method, suffix, body string) (int, map[string]any) {
	s.t.Helper()
	rec := s.do(req{method: method, path: fmt.Sprintf("/api/v1/accounts/%d/companies%s", s.account.ID, suffix), body: body, cookie: s.cookie})
	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}

func TestCompaniesCreateListSearchShow(t *testing.T) {
	s := newScene(t)
	code, body := s.companyRequest("POST", "", `{"company":{"name":"Acme","domain":"acme.example","description":"Support","custom_attributes":{"industry":"tech"}}}`)
	if code != http.StatusOK {
		t.Fatalf("create %d: %+v", code, body)
	}
	company := body["payload"].(map[string]any)
	id := int64(company["id"].(float64))
	for key, want := range map[string]any{"name": "Acme", "domain": "acme.example", "description": "Support", "avatar_url": ""} {
		if company[key] != want {
			t.Errorf("%s = %v want %v", key, company[key], want)
		}
	}
	if company["contacts_count"] != nil {
		t.Errorf("nullable count: %v", company["contacts_count"])
	}
	if _, ok := company["created_at"].(float64); !ok {
		t.Error("created_at must be epoch")
	}
	if _, ok := company["last_activity_at"]; ok {
		t.Error("nil last_activity_at must be omitted")
	}
	if company["custom_attributes"].(map[string]any)["industry"] != "tech" {
		t.Error("custom attributes lost")
	}
	if _, ok := company["additional_attributes"]; ok {
		t.Error("additional_attributes absent in original view")
	}
	code, body = s.companyRequest("GET", "?sort=name&page=1", "")
	if code != 200 || body["meta"].(map[string]any)["total_count"] != float64(1) || body["meta"].(map[string]any)["page"] != "1" {
		t.Fatalf("index %d: %+v", code, body)
	}
	code, body = s.companyRequest("GET", "/search?q=ACME.EXAMPLE", "")
	if code != 200 || len(payloadList(t, body)) != 1 {
		t.Fatalf("search %d: %+v", code, body)
	}
	code, body = s.companyRequest("GET", fmt.Sprintf("/%d", id), "")
	if code != 200 || body["payload"].(map[string]any)["name"] != "Acme" {
		t.Fatalf("show %d: %+v", code, body)
	}
}

func TestCompaniesPaginationSortingAndAccountScope(t *testing.T) {
	s := newScene(t)
	for i := 0; i < 26; i++ {
		code, _ := s.companyRequest("POST", "", fmt.Sprintf(`{"company":{"name":"Company %02d"}}`, i))
		if code != 200 {
			t.Fatalf("create %d", code)
		}
	}
	code, body := s.companyRequest("GET", "?sort=-name&page=2", "")
	items := payloadList(t, body)
	if code != 200 || len(items) != 1 || items[0]["name"] != "Company 00" || body["meta"].(map[string]any)["total_count"] != float64(26) {
		t.Fatalf("page %d: %+v", code, body)
	}
	otherAccount := s.f.Account()
	otherUser := s.f.User(otherAccount)
	other := scene{app: s.app, account: otherAccount, cookie: sessionCookie(s.signIn(otherUser.Email, factory.DefaultPassword)).Value}
	_, created := other.companyRequest("POST", "", `{"company":{"name":"Other account"}}`)
	id := int64(created["payload"].(map[string]any)["id"].(float64))
	code, _ = s.companyRequest("GET", fmt.Sprintf("/%d", id), "")
	if code != 404 {
		t.Fatalf("cross account show = %d", code)
	}
	code, body = s.companyRequest("GET", "/search?q=Other", "")
	if code != 200 || len(payloadList(t, body)) != 0 {
		t.Fatalf("cross account search %d: %+v", code, body)
	}
}

func TestCompaniesValidation(t *testing.T) {
	s := newScene(t)
	for _, body := range []string{`{"company":{"name":" "}}`, `{"company":{"name":"Acme","domain":"https://acme.com"}}`, `{"company":{"domain":"acme.com"}}`} {
		code, _ := s.companyRequest("POST", "", body)
		if code != 422 {
			t.Errorf("%s status %d", body, code)
		}
	}
	s.companyRequest("POST", "", `{"company":{"name":"Acme","domain":"acme.com"}}`)
	code, _ := s.companyRequest("POST", "", `{"company":{"name":"Duplicate","domain":"acme.com"}}`)
	if code != 422 {
		t.Errorf("duplicate domain %d", code)
	}
	code, _ = s.companyRequest("GET", "/search?q=+", "")
	if code != 422 {
		t.Errorf("blank search %d", code)
	}
	code, _ = s.companyRequest("GET", "/invalid", "")
	if code != 404 {
		t.Errorf("invalid id %d", code)
	}
}
