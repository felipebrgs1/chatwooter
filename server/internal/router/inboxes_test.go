package router_test

import (
	"net/http"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
)

func TestInboxesIndexReturnsChatwootPayloadWithoutSecrets(t *testing.T) {
	s := newScene(t) // s.inbox é Telegram
	s.f.WhatsappInbox(s.account, func(i *factory.Inbox) { i.Name = "zap" })

	var body map[string][]map[string]any
	if code := s.getJSON("/inboxes", &body); code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	payload := body["payload"]
	if len(payload) != 2 {
		t.Fatalf("payload: %+v", body)
	}
	for _, in := range payload {
		for _, secret := range []string{"bot_token", "provider_config", "api_key"} {
			if _, ok := in[secret]; ok {
				t.Fatalf("%s vazou no index: %+v", secret, in)
			}
		}
		for _, key := range []string{"id", "channel_id", "name", "channel_type", "avatar_url", "working_hours", "timezone", "provider"} {
			if _, ok := in[key]; !ok {
				t.Fatalf("falta %s: %+v", key, in)
			}
		}
	}
	tg, wa := payload[0], payload[1]
	if tg["channel_type"] != "Channel::Telegram" || tg["name"] != s.inbox.Name {
		t.Fatalf("telegram: %+v", tg)
	}
	if _, ok := tg["bot_name"]; !ok {
		t.Fatalf("telegram sem bot_name: %+v", tg)
	}
	if _, ok := tg["message_templates"]; ok {
		t.Fatalf("message_templates é só do WhatsApp: %+v", tg)
	}
	if wa["channel_type"] != "Channel::Whatsapp" || wa["phone_number"] == nil || wa["provider"] != "whatsapp_cloud" {
		t.Fatalf("whatsapp: %+v", wa)
	}
	if tpl, ok := wa["message_templates"].([]any); !ok || len(tpl) != 0 {
		t.Fatalf("message_templates deve ser [] quando não é array: %+v", wa["message_templates"])
	}
}

func TestInboxesIndexForAgentsListsOnlyTheirInboxes(t *testing.T) {
	s := newScene(t)
	agent := s.f.User(s.account)
	s.f.InboxMember(s.inbox, agent)
	s.f.TelegramInbox(s.account)
	s.cookie = sessionCookie(s.signIn(agent.Email, factory.DefaultPassword)).Value

	var body map[string][]map[string]any
	if code := s.getJSON("/inboxes", &body); code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	if len(body["payload"]) != 1 || body["payload"][0]["id"] != float64(s.inbox.ID) {
		t.Fatalf("agente vê só a própria inbox: %+v", body)
	}
}
