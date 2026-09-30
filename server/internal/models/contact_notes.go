package models

import (
	"context"
	"strings"
	"time"
)

// Note é a nota de um agente sobre o contato (tabela notes); User some se o autor não for mais da conta.
type Note struct {
	ID        int64
	Content   string
	AccountID int32
	ContactID int32
	User      *Agent
	CreatedAt time.Time
	UpdatedAt time.Time
}

// ContactNotes é o contacts/notes_controller.rb: qualquer membro da conta lê, cria, edita e apaga
// (o controller não tem policy própria; só o escopo do contato).
type ContactNotes struct {
	db DB
}

func NewContactNotes(db DB) *ContactNotes { return &ContactNotes{db: db} }

const noteColumns = `n.id, n.content, n.account_id, n.contact_id, n.user_id, n.created_at, n.updated_at`

func (n *ContactNotes) contactExists(ctx context.Context, accountID, contactID int32) error {
	return (&Contacts{db: n.db}).exists(ctx, accountID, contactID)
}

// List é o index: @contact.notes.latest (mais recentes primeiro).
func (n *ContactNotes) List(ctx context.Context, accountID, contactID int32) ([]Note, error) {
	if err := n.contactExists(ctx, accountID, contactID); err != nil {
		return nil, err
	}
	return n.query(ctx, accountID, `SELECT `+noteColumns+` FROM notes n WHERE n.account_id = $1 AND n.contact_id = $2
		ORDER BY n.created_at DESC, n.id DESC`, accountID, contactID)
}

// Get é o show (e o `note` dos demais): a nota precisa ser do contato, que precisa ser da conta.
func (n *ContactNotes) Get(ctx context.Context, accountID, contactID int32, id int64) (Note, error) {
	if err := n.contactExists(ctx, accountID, contactID); err != nil {
		return Note{}, err
	}
	notes, err := n.query(ctx, accountID, `SELECT `+noteColumns+` FROM notes n WHERE n.account_id = $1 AND n.contact_id = $2
		AND n.id = $3`, accountID, contactID, id)
	if err != nil {
		return Note{}, err
	}
	if len(notes) == 0 {
		return Note{}, ErrNotFound
	}
	return notes[0], nil
}

// Create grava a nota com o autor da sessão; conteúdo em branco é o RecordInvalid do `validates :content, presence`.
func (n *ContactNotes) Create(ctx context.Context, accountID, contactID, userID int32, content string) (Note, error) {
	if err := n.contactExists(ctx, accountID, contactID); err != nil {
		return Note{}, err
	}
	if strings.TrimSpace(content) == "" {
		invalid := &ValidationError{}
		invalid.add("content", "Content can't be blank")
		return Note{}, invalid
	}
	var id int64
	if err := n.db.QueryRow(ctx, `INSERT INTO notes (content, account_id, contact_id, user_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, now(), now()) RETURNING id`, content, accountID, contactID, userID).Scan(&id); err != nil {
		return Note{}, err
	}
	return n.Get(ctx, accountID, contactID, id)
}

// Update troca o conteúdo; como o note_params do Chatwoot, o autor passa a ser quem editou.
// O controller usa `update` sem bang: conteúdo em branco não grava e devolve a nota como estava.
func (n *ContactNotes) Update(ctx context.Context, accountID, contactID int32, id int64, userID int32, content string) (Note, error) {
	if _, err := n.Get(ctx, accountID, contactID, id); err != nil {
		return Note{}, err
	}
	if strings.TrimSpace(content) != "" {
		if _, err := n.db.Exec(ctx, `UPDATE notes SET content = $2, user_id = $3, updated_at = now() WHERE id = $1`,
			id, content, userID); err != nil {
			return Note{}, err
		}
	}
	return n.Get(ctx, accountID, contactID, id)
}

func (n *ContactNotes) Delete(ctx context.Context, accountID, contactID int32, id int64) error {
	if _, err := n.Get(ctx, accountID, contactID, id); err != nil {
		return err
	}
	_, err := n.db.Exec(ctx, `DELETE FROM notes WHERE id = $1`, id)
	return err
}

func (n *ContactNotes) query(ctx context.Context, accountID int32, sql string, args ...any) ([]Note, error) {
	rows, err := n.db.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	notes := []Note{}
	var userIDs []int64
	authors := []*int64{}
	for rows.Next() {
		var note Note
		var account, contact int64
		var user *int64
		if err := rows.Scan(&note.ID, &note.Content, &account, &contact, &user, &note.CreatedAt, &note.UpdatedAt); err != nil {
			return nil, err
		}
		note.AccountID, note.ContactID = toInt32(account), toInt32(contact)
		notes = append(notes, note)
		authors = append(authors, user)
		if user != nil {
			userIDs = append(userIDs, *user)
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()
	agents, err := agentsByID(ctx, n.db, accountID, userIDs)
	if err != nil {
		return nil, err
	}
	for i, user := range authors {
		if user == nil {
			continue
		}
		if a, ok := agents[*user]; ok {
			notes[i].User = &a
		}
	}
	return notes, nil
}
