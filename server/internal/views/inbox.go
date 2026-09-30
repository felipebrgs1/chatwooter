package views

import (
	"encoding/json"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

// InboxJSON espelha api/v1/models/_inbox.json.jbuilder para os canais do v1 (Telegram e WhatsApp).
// Os atributos de widget, Twilio, e-mail e API (nulos nesses canais) não são emitidos, e o provider_config
// que o Chatwoot manda a administradores fica de fora: aqui ele é cifrado e só sai em telas de configuração.
type InboxJSON struct {
	ID                         int32             `json:"id"`
	AvatarURL                  string            `json:"avatar_url"`
	ChannelID                  int32             `json:"channel_id"`
	Name                       string            `json:"name"`
	ChannelType                string            `json:"channel_type"`
	GreetingEnabled            bool              `json:"greeting_enabled"`
	GreetingMessage            *string           `json:"greeting_message"`
	WorkingHoursEnabled        bool              `json:"working_hours_enabled"`
	EnableEmailCollect         bool              `json:"enable_email_collect"`
	CSATSurveyEnabled          bool              `json:"csat_survey_enabled"`
	CSATConfig                 json.RawMessage   `json:"csat_config"`
	EnableAutoAssignment       bool              `json:"enable_auto_assignment"`
	AutoAssignmentConfig       json.RawMessage   `json:"auto_assignment_config"`
	OutOfOfficeMessage         *string           `json:"out_of_office_message"`
	WorkingHours               []WorkingHourJSON `json:"working_hours"`
	Timezone                   string            `json:"timezone"`
	CallbackWebhookURL         *string           `json:"callback_webhook_url"`
	AllowMessagesAfterResolved bool              `json:"allow_messages_after_resolved"`
	LockToSingleConversation   bool              `json:"lock_to_single_conversation"`
	SenderNameType             string            `json:"sender_name_type"`
	BusinessName               *string           `json:"business_name"`
	PhoneNumber                *string           `json:"phone_number"`
	Provider                   *string           `json:"provider"`
	*telegramInboxJSON
	*whatsappInboxJSON
}

type telegramInboxJSON struct {
	BotName *string `json:"bot_name"`
}

type whatsappInboxJSON struct {
	MessageTemplates        json.RawMessage `json:"message_templates"`
	ReauthorizationRequired bool            `json:"reauthorization_required"`
}

type WorkingHourJSON struct {
	DayOfWeek    int32  `json:"day_of_week"`
	ClosedAllDay *bool  `json:"closed_all_day"`
	OpenHour     *int32 `json:"open_hour"`
	OpenMinutes  *int32 `json:"open_minutes"`
	CloseHour    *int32 `json:"close_hour"`
	CloseMinutes *int32 `json:"close_minutes"`
	OpenAllDay   *bool  `json:"open_all_day"`
}

func Inboxes(inboxes []models.Inbox) map[string][]InboxJSON {
	out := make([]InboxJSON, 0, len(inboxes))
	for _, in := range inboxes {
		out = append(out, Inbox(in))
	}
	return map[string][]InboxJSON{"payload": out}
}

func Inbox(in models.Inbox) InboxJSON {
	hours := make([]WorkingHourJSON, 0, len(in.WorkingHours))
	for _, h := range in.WorkingHours {
		hours = append(hours, WorkingHourJSON(h))
	}
	out := InboxJSON{
		ID: in.ID, ChannelID: in.ChannelID, Name: in.Name, ChannelType: in.ChannelType,
		GreetingEnabled: in.GreetingEnabled, GreetingMessage: in.GreetingMessage,
		WorkingHoursEnabled: in.WorkingHoursEnabled, EnableEmailCollect: in.EnableEmailCollect,
		CSATSurveyEnabled: in.CSATSurveyEnabled, CSATConfig: in.CSATConfig,
		EnableAutoAssignment: in.EnableAutoAssignment, AutoAssignmentConfig: in.AutoAssignmentConfig,
		OutOfOfficeMessage: in.OutOfOfficeMessage, WorkingHours: hours, Timezone: in.Timezone,
		// o webhook do WhatsApp (FRONTEND_URL/webhooks/whatsapp/:phone) entra com o canal, na fase de canais
		CallbackWebhookURL:         nil,
		AllowMessagesAfterResolved: in.AllowMessagesAfterResolved,
		LockToSingleConversation:   in.LockToSingleConversation,
		SenderNameType:             in.SenderNameType, BusinessName: in.BusinessName,
		PhoneNumber: in.PhoneNumber, Provider: in.Provider,
	}
	switch in.ChannelType {
	case "Channel::Telegram":
		out.telegramInboxJSON = &telegramInboxJSON{BotName: in.BotName}
	case "Channel::Whatsapp":
		// message_templates.is_a?(Array) ? message_templates : []; reauthorization só existe no embedded signup
		templates := in.MessageTemplates
		if len(templates) == 0 || templates[0] != '[' {
			templates = json.RawMessage("[]")
		}
		out.whatsappInboxJSON = &whatsappInboxJSON{MessageTemplates: templates}
	}
	return out
}
