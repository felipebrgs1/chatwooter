package views

import (
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

// RecordInvalid é o render_record_invalid do RequestExceptionHandler: o front lê `attributes` para saber
// se o conflito foi de e-mail ou de telefone (DuplicateContactException).
func RecordInvalid(e *models.ValidationError) map[string]any {
	return map[string]any{"message": e.Error(), "attributes": e.Attributes}
}

// LabelsPayload é o contacts/labels/{index,create}.json.jbuilder: {payload: [títulos]}.
func LabelsPayload(labels []string) map[string][]string {
	if labels == nil {
		labels = []string{}
	}
	return map[string][]string{"payload": labels}
}

// ContactConversations é o contacts/conversations/index.json.jbuilder.
func ContactConversations(items []models.ConversationItem) map[string][]ConversationJSON {
	out := make([]ConversationJSON, 0, len(items))
	for _, it := range items {
		out = append(out, Conversation(it))
	}
	return map[string][]ConversationJSON{"payload": out}
}

// NoteJSON espelha _note.json.jbuilder. O original escreve `json.account_id json.account_id` (e o mesmo para
// contact_id), o que não emite o id; aqui saem os ids de verdade.
type NoteJSON struct {
	ID        int64      `json:"id"`
	Content   string     `json:"content"`
	AccountID int32      `json:"account_id"`
	ContactID int32      `json:"contact_id"`
	User      *AgentJSON `json:"user,omitempty"`
	CreatedAt int64      `json:"created_at"`
	UpdatedAt int64      `json:"updated_at"`
}

func Note(n models.Note) NoteJSON {
	out := NoteJSON{
		ID: n.ID, Content: n.Content, AccountID: n.AccountID, ContactID: n.ContactID,
		CreatedAt: n.CreatedAt.Unix(), UpdatedAt: n.UpdatedAt.Unix(),
	}
	if n.User != nil {
		a := Agent(*n.User)
		out.User = &a
	}
	return out
}

func Notes(notes []models.Note) []NoteJSON {
	out := make([]NoteJSON, 0, len(notes))
	for _, n := range notes {
		out = append(out, Note(n))
	}
	return out
}
