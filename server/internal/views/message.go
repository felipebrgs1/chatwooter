package views

import (
	"encoding/json"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

type AttachmentJSON struct {
	ID        int32   `json:"id"`
	MessageID int32   `json:"message_id"`
	FileType  string  `json:"file_type"`
	AccountID int32   `json:"account_id"`
	Extension *string `json:"extension"`
	DataURL   string  `json:"data_url"`
	ThumbURL  string  `json:"thumb_url"`
	FileSize  int32   `json:"file_size"`
}

// MessageJSON espelha api/v1/models/_message.json.jbuilder.
type MessageJSON struct {
	ID                int32            `json:"id"`
	Content           *string          `json:"content"`
	InboxID           int32            `json:"inbox_id"`
	EchoID            string           `json:"echo_id,omitempty"`
	ConversationID    int32            `json:"conversation_id"`
	MessageType       int32            `json:"message_type"`
	ContentType       string           `json:"content_type"`
	Status            string           `json:"status"`
	ContentAttributes json.RawMessage  `json:"content_attributes"`
	CreatedAt         int64            `json:"created_at"`
	Private           bool             `json:"private"`
	SourceID          *string          `json:"source_id"`
	Sender            any              `json:"sender,omitempty"`
	Attachments       []AttachmentJSON `json:"attachments,omitempty"`
}

func sender(s *models.Sender) any {
	if s == nil {
		return nil
	}
	if s.Type == "user" {
		return map[string]any{
			"id": s.ID, "name": s.Name, "available_name": s.AvailableName, "avatar_url": "", "type": "user",
			"availability_status": s.AvailabilityStatus, "thumbnail": "",
		}
	}
	return map[string]any{
		"additional_attributes": s.AdditionalAttrs, "custom_attributes": s.CustomAttrs, "email": nilIfEmpty(s.Email),
		"id": s.ID, "identifier": nilIfEmpty(s.Identifier), "name": s.Name, "phone_number": nilIfEmpty(s.PhoneNumber),
		"thumbnail": "", "blocked": s.Blocked, "type": "contact",
	}
}

func Message(m models.Message) MessageJSON {
	out := MessageJSON{
		ID: m.ID, Content: m.Content, InboxID: m.InboxID, EchoID: m.EchoID, ConversationID: m.ConversationID,
		MessageType: m.MessageType, ContentType: m.ContentType, Status: m.Status, ContentAttributes: m.ContentAttributes,
		CreatedAt: m.CreatedAt.Unix(), Private: m.Private, SourceID: m.SourceID, Sender: sender(m.Sender),
	}
	for _, a := range m.Attachments {
		out.Attachments = append(out.Attachments, AttachmentJSON{
			ID: a.ID, MessageID: a.MessageID, FileType: a.FileType, AccountID: a.AccountID, Extension: nilIfEmpty(a.Extension),
			DataURL: a.DataURL, ThumbURL: a.ThumbURL, FileSize: a.FileSize,
		})
	}
	return out
}

func messagePtr(m *models.Message) *MessageJSON {
	if m == nil {
		return nil
	}
	v := Message(*m)
	return &v
}

// MessagesIndex espelha accounts/conversations/messages/index.json.jbuilder.
func MessagesIndex(c models.ConversationItem, msgs []models.Message) map[string]any {
	payload := make([]MessageJSON, 0, len(msgs))
	for _, m := range msgs {
		payload = append(payload, Message(m))
	}
	contact := sender(&models.Sender{
		ID: c.Contact.ID, Type: "contact", Name: c.Contact.Name, Email: c.Contact.Email,
		PhoneNumber: c.Contact.PhoneNumber, Identifier: c.Contact.Identifier, Blocked: c.Contact.Blocked,
		AdditionalAttrs: c.Contact.AdditionalAttributes, CustomAttrs: c.Contact.CustomAttributes,
	})
	meta := map[string]any{
		"labels": c.Labels, "additional_attributes": c.AdditionalAttrs, "contact": contact,
		"agent_last_seen_at": railsTimePtr(c.AgentLastSeenAt), "assignee_last_seen_at": railsTimePtr(c.AssigneeLastSeenAt),
	}
	if c.Assignee != nil {
		meta["assignee"] = sender(&models.Sender{
			ID: c.Assignee.ID, Type: "user", Name: c.Assignee.Name,
			AvailableName: c.Assignee.AvailableName, AvailabilityStatus: c.Assignee.AvailabilityStatus,
		})
	}
	return map[string]any{"meta": meta, "payload": payload}
}
