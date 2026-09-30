package router_test

import (
	"encoding/json"
	"net/http"
	"sort"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

// ids devolve os display_ids do payload de /conversations/filter, em ordem crescente.
func filteredIDs(t *testing.T, body map[string]any) []int {
	t.Helper()
	payload, ok := body["payload"].([]any)
	if !ok {
		t.Fatalf("sem payload: %v", body)
	}
	out := []int{}
	for _, it := range payload {
		out = append(out, int(it.(map[string]any)["id"].(float64)))
	}
	sort.Ints(out)
	return out
}

func sameIDs(t *testing.T, got []int, want ...int32) {
	t.Helper()
	w := []int{}
	for _, id := range want {
		w = append(w, int(id))
	}
	sort.Ints(w)
	if len(got) != len(w) {
		t.Fatalf("ids = %v, quero %v", got, w)
	}
	for i := range got {
		if got[i] != w[i] {
			t.Fatalf("ids = %v, quero %v", got, w)
		}
	}
}

func TestConversationsFilterCombinesConditionsWithAndOr(t *testing.T) {
	s := newScene(t)
	open := s.conv()
	s.f.Label(open, "vip")
	pending := s.conv(func(c *factory.Conversation) { c.Status = 2 })
	resolvedVip := s.conv(func(c *factory.Conversation) { c.Status = 1 })
	s.f.Label(resolvedVip, "vip")

	code, body := s.post("/filter", `{"payload":[
		{"attribute_key":"status","filter_operator":"equal_to","values":["open"],"query_operator":"and"},
		{"attribute_key":"labels","filter_operator":"equal_to","values":["vip"]}]}`)
	if code != http.StatusOK {
		t.Fatalf("status = %d: %v", code, body)
	}
	sameIDs(t, filteredIDs(t, body), open.DisplayID)

	_, body = s.post("/filter", `{"payload":[
		{"attribute_key":"status","filter_operator":"equal_to","values":["pending"],"query_operator":"OR"},
		{"attribute_key":"labels","filter_operator":"equal_to","values":["vip"]}]}`)
	sameIDs(t, filteredIDs(t, body), open.DisplayID, pending.DisplayID, resolvedVip.DisplayID)
}

func TestConversationsFilterReturnsCountsLikeChatwoot(t *testing.T) {
	s := newScene(t)
	id := s.admin.ID
	s.conv(func(c *factory.Conversation) { c.AssigneeID = &id })
	s.conv()
	s.conv(func(c *factory.Conversation) { c.Status = 1 })

	_, body := s.post("/filter", `{"payload":[{"attribute_key":"status","filter_operator":"equal_to","values":["open"]}]}`)
	meta := body["meta"].(map[string]any)
	if meta["mine_count"] != float64(1) || meta["unassigned_count"] != float64(1) || meta["all_count"] != float64(2) {
		t.Errorf("meta = %v", meta)
	}
	if _, ok := meta["assigned_count"]; ok {
		t.Errorf("filter.json.jbuilder não devolve assigned_count: %v", meta)
	}
}

func TestConversationsFilterStandardAttributes(t *testing.T) {
	s := newScene(t)
	other := s.f.TelegramInbox(s.account)
	team := s.f.Team(s.account)
	agent := s.admin.ID
	high := int32(2)
	old := time.Date(2024, 1, 10, 12, 0, 0, 0, time.UTC)

	assigned := s.conv(func(c *factory.Conversation) { c.AssigneeID = &agent; c.TeamID = &team.ID; c.Priority = &high })
	elsewhere := s.f.Conversation(s.account, other, s.contact, func(c *factory.Conversation) {
		c.CreatedAt = &old
		c.AdditionalAttrs = map[string]any{"browser_language": "pt", "referer": "https://acme.inc/pricing"}
	})

	cases := []struct {
		name, payload string
		want          []int32
	}{
		{"assignee presente", `{"attribute_key":"assignee_id","filter_operator":"is_present","values":[]}`, []int32{assigned.DisplayID}},
		{"assignee ausente", `{"attribute_key":"assignee_id","filter_operator":"is_not_present","values":[]}`, []int32{elsewhere.DisplayID}},
		{"inbox diferente", `{"attribute_key":"inbox_id","filter_operator":"not_equal_to","values":[` + itoa(s.inbox.ID) + `]}`, []int32{elsewhere.DisplayID}},
		{"time", `{"attribute_key":"team_id","filter_operator":"equal_to","values":["` + itoa(team.ID) + `"]}`, []int32{assigned.DisplayID}},
		{"prioridade", `{"attribute_key":"priority","filter_operator":"equal_to","values":["high"]}`, []int32{assigned.DisplayID}},
		{"display_id contém", `{"attribute_key":"display_id","filter_operator":"contains","values":["` + itoa(elsewhere.DisplayID) + `"]}`, []int32{elsewhere.DisplayID}},
		{"idioma do navegador", `{"attribute_key":"browser_language","filter_operator":"equal_to","values":["pt"]}`, []int32{elsewhere.DisplayID}},
		{"referer contém", `{"attribute_key":"referer","filter_operator":"contains","values":["pricing"]}`, []int32{elsewhere.DisplayID}},
		{"criada antes de", `{"attribute_key":"created_at","filter_operator":"is_less_than","values":["2024-02-01"]}`, []int32{elsewhere.DisplayID}},
		{"criada depois de (fuso)", `{"attribute_key":"created_at","filter_operator":"is_greater_than","values":["2024-02-01"],"timezone":"America/Sao_Paulo"}`, []int32{assigned.DisplayID}},
		{"criada há mais de N dias", `{"attribute_key":"created_at","filter_operator":"days_before","values":["30"]}`, []int32{elsewhere.DisplayID}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			code, body := s.post("/filter", `{"payload":[`+tc.payload+`]}`)
			if code != http.StatusOK {
				t.Fatalf("status = %d: %v", code, body)
			}
			sameIDs(t, filteredIDs(t, body), tc.want...)
		})
	}
}

func TestConversationsFilterCustomAttributes(t *testing.T) {
	s := newScene(t)
	s.f.CustomAttributeDefinition(s.account, "plano", 0, 0)
	s.f.CustomAttributeDefinition(s.account, "valor", 0, 1)
	pro := s.conv(func(c *factory.Conversation) { c.CustomAttrs = map[string]any{"plano": "Pro", "valor": 150} })
	free := s.conv(func(c *factory.Conversation) { c.CustomAttrs = map[string]any{"plano": "free", "valor": 10} })
	none := s.conv()

	_, body := s.post("/filter", `{"payload":[{"attribute_key":"plano","filter_operator":"equal_to","values":["pro"]}]}`)
	sameIDs(t, filteredIDs(t, body), pro.DisplayID)

	// not_equal_to também traz quem não tem o atributo (not_in_custom_attr_query)
	_, body = s.post("/filter", `{"payload":[{"attribute_key":"plano","filter_operator":"not_equal_to","values":["pro"]}]}`)
	sameIDs(t, filteredIDs(t, body), free.DisplayID, none.DisplayID)

	_, body = s.post("/filter", `{"payload":[{"attribute_key":"valor","filter_operator":"is_greater_than","values":["100"]}]}`)
	sameIDs(t, filteredIDs(t, body), pro.DisplayID)
}

func TestConversationsFilterRejectsInvalidPayloads(t *testing.T) {
	s := newScene(t)
	cases := []struct{ name, payload, err string }{
		{
			"atributo desconhecido", `[{"attribute_key":"nada","filter_operator":"equal_to","values":["x"]}]`,
			"Invalid attribute key - [nada]. The key should be one of [status,assignee_id,inbox_id,team_id,contact_id,priority,display_id,campaign_id,labels,browser_language,conversation_language,referer,created_at,last_activity_at,mail_subject] or a custom attribute defined in the account.",
		},
		{
			"operador não permitido", `[{"attribute_key":"status","filter_operator":"contains","values":["open"]}]`,
			"Invalid operator. The allowed operators for status are [equal_to,not_equal_to].",
		},
		{
			"operador lógico sobrando no fim", `[{"attribute_key":"status","filter_operator":"equal_to","values":["open"],"query_operator":"and"}]`,
			`Query operator must be either "AND" or "OR".`,
		},
		{
			"operador lógico inválido", `[{"attribute_key":"status","filter_operator":"equal_to","values":["open"],"query_operator":"xor"},{"attribute_key":"status","filter_operator":"equal_to","values":["open"]}]`,
			`Query operator must be either "AND" or "OR".`,
		},
		{
			"sem valores", `[{"attribute_key":"inbox_id","filter_operator":"equal_to","values":[]}]`,
			"Invalid value. The values provided for inbox_id are invalid",
		},
		{
			"status que não é texto", `[{"attribute_key":"status","filter_operator":"equal_to","values":[1]}]`,
			"Invalid value. The values provided for status are invalid",
		},
		{
			"dias fora do intervalo", `[{"attribute_key":"created_at","filter_operator":"days_before","values":["0"]}]`,
			"Invalid value. The values provided for created_at are invalid",
		},
		{
			"fuso inválido", `[{"attribute_key":"created_at","filter_operator":"is_less_than","values":["2024-01-01"],"timezone":"Lua/Base"}]`,
			"Invalid value. The values provided for timezone are invalid",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			code, body := s.post("/filter", `{"payload":`+tc.payload+`}`)
			if code != http.StatusUnprocessableEntity || body["error"] != tc.err {
				t.Fatalf("status = %d, body = %v", code, body)
			}
		})
	}
}

func TestConversationsFilterPaginatesAndSorts(t *testing.T) {
	s := newScene(t)
	base := time.Now().UTC().Add(-time.Hour)
	var first, last factory.Conversation
	for i := range 26 {
		at := base.Add(time.Duration(i) * time.Minute)
		c := s.conv(func(c *factory.Conversation) { c.LastActivityAt = &at })
		if i == 0 {
			first = c
		}
		last = c
	}
	payload := `{"payload":[{"attribute_key":"status","filter_operator":"equal_to","values":["open"]}]}`

	_, body := s.post("/filter?sort_by=last_activity_at_asc", payload)
	items := body["payload"].([]any)
	if len(items) != 25 || items[0].(map[string]any)["id"] != float64(first.DisplayID) {
		t.Fatalf("página 1: %d itens, primeiro %v", len(items), items[0].(map[string]any)["id"])
	}
	_, body = s.post("/filter?sort_by=last_activity_at_asc&page=2", payload)
	sameIDs(t, filteredIDs(t, body), last.DisplayID)
}

func TestConversationsFilterAgentOnlySeesOwnInboxes(t *testing.T) {
	s := newScene(t)
	agent := s.f.User(s.account)
	other := s.f.TelegramInbox(s.account)
	s.f.InboxMember(s.inbox, agent)
	mine := s.conv()
	s.f.Conversation(s.account, other, s.contact)

	cookie := sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value
	rec := s.do(req{
		method: "POST", path: s.path("/filter"), cookie: cookie,
		body: `{"payload":[{"attribute_key":"status","filter_operator":"equal_to","values":["open"]}]}`,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body)
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	sameIDs(t, filteredIDs(t, body), mine.DisplayID)
}
