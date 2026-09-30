package models

import (
	"context"
	"encoding/json"

	"github.com/jackc/pgx/v5/pgtype"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

// Inbox é a caixa de entrada com os campos públicos do canal (Telegram: bot_name; WhatsApp: número,
// provedor e templates). Segredos do canal ficam só em InboxConfigs.
type Inbox struct {
	ID                         int32
	ChannelID                  int32
	Name                       string
	ChannelType                string
	GreetingEnabled            bool
	GreetingMessage            *string
	WorkingHoursEnabled        bool
	EnableEmailCollect         bool
	CSATSurveyEnabled          bool
	CSATConfig                 json.RawMessage
	EnableAutoAssignment       bool
	AutoAssignmentConfig       json.RawMessage
	OutOfOfficeMessage         *string
	WorkingHours               []WorkingHour
	Timezone                   string
	AllowMessagesAfterResolved bool
	LockToSingleConversation   bool
	SenderNameType             string
	BusinessName               *string
	BotName                    *string
	PhoneNumber                *string
	Provider                   *string
	MessageTemplates           json.RawMessage
}

// WorkingHour é um dia do weekly_schedule (OutOfOffisable#weekly_schedule).
type WorkingHour struct {
	DayOfWeek    int32  `json:"day_of_week"`
	ClosedAllDay *bool  `json:"closed_all_day"`
	OpenHour     *int32 `json:"open_hour"`
	OpenMinutes  *int32 `json:"open_minutes"`
	CloseHour    *int32 `json:"close_hour"`
	CloseMinutes *int32 `json:"close_minutes"`
	OpenAllDay   *bool  `json:"open_all_day"`
}

type Inboxes struct {
	q *sqlc.Queries
}

func NewInboxes(db sqlc.DBTX) *Inboxes { return &Inboxes{q: sqlc.New(db)} }

var senderNameTypes = map[int32]string{0: "friendly", 1: "professional"}

// List devolve as inboxes da conta por nome. memberID limita às inboxes do agente (User#assigned_inboxes);
// nil é o administrador, que vê todas.
func (in *Inboxes) List(ctx context.Context, accountID int32, memberID *int32) ([]Inbox, error) {
	params := sqlc.ListInboxesParams{AccountID: accountID}
	if memberID != nil {
		params.MemberID = pgtype.Int4{Int32: *memberID, Valid: true}
	}
	rows, err := in.q.ListInboxes(ctx, params)
	if err != nil {
		return nil, err
	}
	out := make([]Inbox, 0, len(rows))
	for _, r := range rows {
		var hours []WorkingHour
		if err := json.Unmarshal(r.WorkingHours, &hours); err != nil {
			return nil, err
		}
		out = append(out, Inbox{
			ID:                         r.ID,
			ChannelID:                  r.ChannelID,
			Name:                       r.Name,
			ChannelType:                r.ChannelType.String,
			GreetingEnabled:            r.GreetingEnabled.Bool,
			GreetingMessage:            textPtr(r.GreetingMessage),
			WorkingHoursEnabled:        r.WorkingHoursEnabled.Bool,
			EnableEmailCollect:         r.EnableEmailCollect.Bool,
			CSATSurveyEnabled:          r.CsatSurveyEnabled.Bool,
			CSATConfig:                 orEmptyObject(r.CsatConfig),
			EnableAutoAssignment:       r.EnableAutoAssignment.Bool,
			AutoAssignmentConfig:       orEmptyObject(r.AutoAssignmentConfig),
			OutOfOfficeMessage:         textPtr(r.OutOfOfficeMessage),
			WorkingHours:               hours,
			Timezone:                   r.Timezone.String,
			AllowMessagesAfterResolved: r.AllowMessagesAfterResolved.Bool,
			LockToSingleConversation:   r.LockToSingleConversation,
			SenderNameType:             senderNameTypes[r.SenderNameType],
			BusinessName:               textPtr(r.BusinessName),
			BotName:                    textPtr(r.BotName),
			PhoneNumber:                textPtr(r.PhoneNumber),
			Provider:                   textPtr(r.Provider),
			MessageTemplates:           r.MessageTemplates,
		})
	}
	return out, nil
}
