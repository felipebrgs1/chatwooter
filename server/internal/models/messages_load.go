package models

import (
	"context"
	"encoding/json"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

var contentTypes = map[int32]string{
	0: "text", 1: "input_text", 2: "input_textarea", 3: "input_email", 4: "input_select", 5: "cards", 6: "form",
	7: "article", 8: "incoming_email", 9: "input_csat", 10: "integrations", 11: "sticker", 12: "voice_call",
}

var messageStatuses = map[int32]string{0: "sent", 1: "delivered", 2: "read", 3: "failed"}

var fileTypes = map[int32]string{
	0: "image", 1: "audio", 2: "video", 3: "file", 4: "location", 5: "fallback", 6: "share", 7: "story_mention",
	8: "contact", 9: "ig_reel", 10: "ig_post", 11: "ig_story", 12: "embed",
}

const messageColumns = `m.id, m.content, m.inbox_id, cv.display_id, m.message_type, m.content_type, COALESCE(m.status, 0),
	COALESCE(m.content_attributes::text, '{}'), m.created_at, m.private, m.source_id, COALESCE(m.sender_type, ''), m.sender_id, cv.contact_id`

// loadMessages carrega mensagens (com remetente e anexos) que satisfazem `where` (alias m = messages).
// $1 é sempre o argumento do filtro; devolve em ordem crescente de id.
func loadMessages(ctx context.Context, db sqlc.DBTX, where string, args ...any) ([]Message, error) {
	rows, err := db.Query(ctx, `SELECT `+messageColumns+` FROM messages m JOIN conversations cv ON cv.id = m.conversation_id
		WHERE `+where+` ORDER BY m.id`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []Message
	var senderTypes []string
	var senderIDs []*int64
	for rows.Next() {
		var m Message
		var contentType, status int32
		var attrs, senderType string
		var senderID, contactID *int64
		var created time.Time
		if err := rows.Scan(&m.ID, &m.Content, &m.InboxID, &m.ConversationID, &m.MessageType, &contentType, &status,
			&attrs, &created, &m.Private, &m.SourceID, &senderType, &senderID, &contactID); err != nil {
			return nil, err
		}
		m.ContentType, m.Status = contentTypes[contentType], messageStatuses[status]
		m.ContentAttributes, m.CreatedAt = json.RawMessage(attrs), created
		// Mensagem recebida sem remetente (dados do app Elixir): o autor é o contato da conversa.
		if senderID == nil && m.MessageType == 0 && contactID != nil {
			senderType, senderID = "Contact", contactID
		}
		msgs = append(msgs, m)
		senderTypes, senderIDs = append(senderTypes, senderType), append(senderIDs, senderID)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()
	if len(msgs) == 0 {
		return msgs, nil
	}

	if err := attachSenders(ctx, db, msgs, senderTypes, senderIDs); err != nil {
		return nil, err
	}
	return msgs, attachFiles(ctx, db, msgs)
}

func attachSenders(ctx context.Context, db sqlc.DBTX, msgs []Message, types []string, ids []*int64) error {
	var userIDs, contactIDs []int64
	for i, id := range ids {
		if id == nil {
			continue
		}
		switch types[i] {
		case "User":
			userIDs = append(userIDs, *id)
		case "Contact":
			contactIDs = append(contactIDs, *id)
		}
	}
	users := map[int64]Sender{}
	if len(userIDs) > 0 {
		rows, err := db.Query(ctx, `SELECT id, name, COALESCE(display_name, ''), COALESCE(availability, 0) FROM users WHERE id = ANY($1)`, userIDs)
		if err != nil {
			return err
		}
		for rows.Next() {
			s := Sender{Type: "user"}
			var display string
			var availability int32
			if err := rows.Scan(&s.ID, &s.Name, &display, &availability); err != nil {
				rows.Close()
				return err
			}
			s.AvailableName = s.Name
			if display != "" {
				s.AvailableName = display
			}
			s.AvailabilityStatus = availabilityName(availability)
			users[int64(s.ID)] = s
		}
		rows.Close()
	}
	contacts := map[int64]Sender{}
	if len(contactIDs) > 0 {
		rows, err := db.Query(ctx, `SELECT id, name, COALESCE(email, ''), COALESCE(phone_number, ''), COALESCE(identifier, ''), blocked,
			additional_attributes, custom_attributes FROM contacts WHERE id = ANY($1)`, contactIDs)
		if err != nil {
			return err
		}
		for rows.Next() {
			s := Sender{Type: "contact"}
			var additional, custom []byte
			if err := rows.Scan(&s.ID, &s.Name, &s.Email, &s.PhoneNumber, &s.Identifier, &s.Blocked, &additional, &custom); err != nil {
				rows.Close()
				return err
			}
			s.AdditionalAttrs, s.CustomAttrs = orEmptyObject(additional), orEmptyObject(custom)
			contacts[int64(s.ID)] = s
		}
		rows.Close()
	}
	for i := range msgs {
		if ids[i] == nil {
			continue
		}
		var s Sender
		var ok bool
		switch types[i] {
		case "User":
			s, ok = users[*ids[i]]
		case "Contact":
			s, ok = contacts[*ids[i]]
		}
		if ok {
			msgs[i].Sender = &s
		}
	}
	return nil
}

func attachFiles(ctx context.Context, db sqlc.DBTX, msgs []Message) error {
	ids := make([]int64, len(msgs))
	index := map[int32]int{}
	for i, m := range msgs {
		ids[i], index[m.ID] = int64(m.ID), i
	}
	rows, err := db.Query(ctx, `SELECT a.id, a.message_id, a.account_id, COALESCE(a.file_type, 3), COALESCE(a.extension, ''),
		COALESCE(s.url, a.external_url, ''), COALESCE(s.size_bytes, 0)
		FROM attachments a LEFT JOIN chatwooter_attachment_storage s ON s.attachment_id = a.id
		WHERE a.message_id = ANY($1) ORDER BY a.id`, ids)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var a Attachment
		var fileType int32
		if err := rows.Scan(&a.ID, &a.MessageID, &a.AccountID, &fileType, &a.Extension, &a.DataURL, &a.FileSize); err != nil {
			return err
		}
		a.FileType = fileTypes[fileType]
		if a.FileType == "image" {
			a.ThumbURL = a.DataURL
		}
		msgs[index[a.MessageID]].Attachments = append(msgs[index[a.MessageID]].Attachments, a)
	}
	return rows.Err()
}
