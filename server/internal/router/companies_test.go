package router_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
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

func TestCompanyUpdateDeleteAndAccountScope(t *testing.T) {
	s := newScene(t)
	_, created := s.companyRequest("POST", "", `{"company":{"name":"Acme","domain":"acme.example","custom_attributes":{"industry":"tech"}}}`)
	id := int64(created["payload"].(map[string]any)["id"].(float64))
	path := fmt.Sprintf("/%d", id)
	code, body := s.companyRequest("PATCH", path, `{"company":{"name":"Renamed","domain":null,"custom_attributes":{"size":10}}}`)
	if code != 200 {
		t.Fatalf("update %d: %v", code, body)
	}
	saved := body["payload"].(map[string]any)
	attrs := saved["custom_attributes"].(map[string]any)
	if saved["name"] != "Renamed" || saved["domain"] != nil || attrs["industry"] != "tech" || attrs["size"] != float64(10) {
		t.Fatalf("update lost data: %v", saved)
	}
	code, _ = s.companyRequest("PUT", path, `{"company":{"name":" "}}`)
	if code != 422 {
		t.Fatalf("invalid update %d", code)
	}
	if code, _ := s.companyRequest("PUT", path, `{"company":{"name":null}}`); code != 422 {
		t.Fatalf("null name %d", code)
	}
	s.companyRequest("POST", "", `{"company":{"name":"Other","domain":"other.example"}}`)
	if code, _ := s.companyRequest("PUT", path, `{"company":{"domain":"other.example"}}`); code != 422 {
		t.Fatalf("duplicate domain %d", code)
	}
	otherAccount := s.f.Account()
	otherUser := s.f.User(otherAccount, func(u *factory.User) { u.Role = 1 })
	other := scene{app: s.app, account: otherAccount, cookie: sessionCookie(s.signIn(otherUser.Email, factory.DefaultPassword)).Value}
	for _, method := range []string{"PUT", "DELETE"} {
		code, _ = other.companyRequest(method, path, `{"company":{"name":"Stolen"}}`)
		if code != 404 {
			t.Fatalf("cross account %s: %d", method, code)
		}
	}
	code, _ = s.companyRequest("DELETE", path, "")
	if code != 200 {
		t.Fatalf("delete %d", code)
	}
	code, _ = s.companyRequest("GET", path, "")
	if code != 404 {
		t.Fatalf("deleted company %d", code)
	}
}

func TestCompanyRenameSyncAndDeletePreserveContacts(t *testing.T) {
	s := newScene(t)
	_, created := s.companyRequest("POST", "", `{"company":{"name":"Acme"}}`)
	id := int64(created["payload"].(map[string]any)["id"].(float64))
	path := fmt.Sprintf("/%d", id)
	_, err := s.f.Pool().Exec(context.Background(), `UPDATE contacts SET company_id=$1, additional_attributes='{"company_name":"Acme","city":"Recife"}' WHERE id=$2`, id, s.contact.ID)
	if err != nil {
		t.Fatal(err)
	}
	if code, _ := s.companyRequest("PUT", path, `{"company":{"name":"Renamed"}}`); code != 200 {
		t.Fatalf("rename %d", code)
	}
	var name string
	if err := s.f.Pool().QueryRow(context.Background(), `SELECT additional_attributes->>'company_name' FROM contacts WHERE id=$1`, s.contact.ID).Scan(&name); err != nil || name != "Renamed" {
		t.Fatalf("sync %q: %v", name, err)
	}
	agent := s.f.User(s.account)
	asAgent := s
	asAgent.cookie = sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value
	if code, _ := asAgent.companyRequest("PUT", path, `{"company":{"description":"Agent edit"}}`); code != 200 {
		t.Fatalf("agent update %d", code)
	}
	if code, _ := asAgent.companyRequest("DELETE", path, ""); code != 401 {
		t.Fatalf("agent delete %d", code)
	}
	if code, _ := s.companyRequest("DELETE", path, ""); code != 200 {
		t.Fatalf("delete %d", code)
	}
	var unlinked bool
	var city string
	if err := s.f.Pool().QueryRow(context.Background(), `SELECT company_id IS NULL AND NOT (additional_attributes ? 'company_name'), additional_attributes->>'city' FROM contacts WHERE id=$1`, s.contact.ID).Scan(&unlinked, &city); err != nil || !unlinked || city != "Recife" {
		t.Fatalf("contact preservation %v %q: %v", unlinked, city, err)
	}
}

func TestCompanyContactsHistoryNotes(t *testing.T) {
	s := newScene(t)
	_, created := s.companyRequest("POST", "", `{"company":{"name":"Acme"}}`)
	id := int64(created["payload"].(map[string]any)["id"].(float64))
	path := fmt.Sprintf("/%d", id)
	code, body := s.companyRequest("POST", path+"/contacts", fmt.Sprintf(`{"contact_id":%d}`, s.contact.ID))
	if code != 200 {
		t.Fatalf("link %d: %v", code, body)
	}
	code, body = s.companyRequest("GET", path+"/contacts", "")
	if code != 200 || len(payloadList(t, body)) != 1 {
		t.Fatalf("contacts %d: %v", code, body)
	}
	ct := payloadList(t, body)[0]
	if ct["company_id"] != float64(id) || ct["linked_to_current_company"] != true || ct["company"].(map[string]any)["name"] != "Acme" {
		t.Fatalf("linked json: %v", ct)
	}
	code, body = s.companyRequest("GET", path+"/contacts/search?q="+url.QueryEscape(s.contact.Name), "")
	if code != 200 || len(payloadList(t, body)) != 0 {
		t.Fatalf("search includes linked %d: %v", code, body)
	}
	s.f.Note(s.contact, s.admin, "Company note", nil)
	conv := s.conv()
	code, body = s.companyRequest("GET", path+"/notes", "")
	if code != 200 || len(payloadList(t, body)) != 1 || payloadList(t, body)[0]["content"] != "Company note" {
		t.Fatalf("notes %d: %v", code, body)
	}
	code, body = s.companyRequest("GET", path+"/conversations", "")
	if code != 200 || len(payloadList(t, body)) != 1 || payloadList(t, body)[0]["id"] != float64(conv.DisplayID) {
		t.Fatalf("history %d: %v", code, body)
	}
	agent := s.f.User(s.account)
	asAgent := s
	asAgent.cookie = sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value
	code, body = asAgent.companyRequest("GET", path+"/conversations", "")
	if code != 200 || len(payloadList(t, body)) != 0 {
		t.Fatalf("history permissions %d: %v", code, body)
	}
	code, _ = s.companyRequest("DELETE", fmt.Sprintf("%s/contacts/%d", path, s.contact.ID), "")
	if code != 200 {
		t.Fatalf("unlink %d", code)
	}
	code, body = s.companyRequest("GET", path+"/contacts", "")
	if code != 200 || len(payloadList(t, body)) != 0 {
		t.Fatalf("unlink result %d: %v", code, body)
	}
}

func TestCompanyAvatarUploadReadRemove(t *testing.T) {
	s := newScene(t)
	_, created := s.companyRequest("POST", "", `{"company":{"name":"Avatar"}}`)
	id := int64(created["payload"].(map[string]any)["id"].(float64))
	path := fmt.Sprintf("/api/v1/accounts/%d/companies/%d", s.account.ID, id)
	var data bytes.Buffer
	if err := png.Encode(&data, image.NewRGBA(image.Rect(0, 0, 2, 2))); err != nil {
		t.Fatal(err)
	}
	var body bytes.Buffer
	form := multipart.NewWriter(&body)
	part, err := form.CreateFormFile("company[avatar]", "avatar.png")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := part.Write(data.Bytes()); err != nil {
		t.Fatal(err)
	}
	if err := form.Close(); err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest("PUT", path, &body)
	request.Header.Set("Content-Type", form.FormDataContentType())
	request.AddCookie(&http.Cookie{Name: cookieName, Value: s.cookie})
	response := httptest.NewRecorder()
	s.handler.ServeHTTP(response, request)
	if response.Code != 200 {
		t.Fatalf("avatar upload %d: %s", response.Code, response.Body.String())
	}
	var payload struct {
		Payload struct {
			URL string `json:"avatar_url"`
		}
	}
	if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if payload.Payload.URL == "" {
		t.Fatal("missing avatar URL")
	}
	imageResponse := s.do(req{method: "GET", path: payload.Payload.URL, cookie: s.cookie})
	if imageResponse.Code != 200 || imageResponse.Header().Get("Content-Type") != "image/png" || !bytes.Equal(imageResponse.Body.Bytes(), data.Bytes()) {
		t.Fatalf("avatar read %d", imageResponse.Code)
	}
	code, _ := s.companyRequest("DELETE", fmt.Sprintf("/%d/avatar", id), "")
	if code != 200 {
		t.Fatalf("avatar remove %d", code)
	}
	imageResponse = s.do(req{method: "GET", path: payload.Payload.URL, cookie: s.cookie})
	if imageResponse.Code != 404 {
		t.Fatalf("removed avatar %d", imageResponse.Code)
	}
}

func TestContactCompanySelectorContract(t *testing.T) {
	s := newScene(t)
	_, created := s.companyRequest("POST", "", `{"company":{"name":"Selected"}}`)
	id := int64(created["payload"].(map[string]any)["id"].(float64))
	code, body := s.send("PUT", fmt.Sprintf("/contacts/%d", s.contact.ID), fmt.Sprintf(`{"company_id":%d}`, id))
	if code != 200 || body["payload"].(map[string]any)["company_id"] != float64(id) {
		t.Fatalf("select %d: %v", code, body)
	}
	code, body = s.send("PUT", fmt.Sprintf("/contacts/%d", s.contact.ID), `{"company_id":null}`)
	if code != 200 || body["payload"].(map[string]any)["company_id"] != nil {
		t.Fatalf("clear %d: %v", code, body)
	}
	otherAccount := s.f.Account()
	otherUser := s.f.User(otherAccount, func(u *factory.User) { u.Role = 1 })
	other := scene{app: s.app, account: otherAccount, cookie: sessionCookie(s.signIn(otherUser.Email, factory.DefaultPassword)).Value}
	_, foreign := other.companyRequest("POST", "", `{"company":{"name":"Foreign"}}`)
	foreignID := int64(foreign["payload"].(map[string]any)["id"].(float64))
	code, _ = s.send("PUT", fmt.Sprintf("/contacts/%d", s.contact.ID), fmt.Sprintf(`{"name":"Must rollback","company_id":%d}`, foreignID))
	if code != 404 {
		t.Fatalf("foreign company %d", code)
	}
	code, body = s.send("GET", fmt.Sprintf("/contacts/%d", s.contact.ID), "")
	if code != 200 || body["payload"].(map[string]any)["name"] == "Must rollback" {
		t.Fatalf("atomic rollback %d: %v", code, body)
	}
}
