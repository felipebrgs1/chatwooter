package controllers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

func contactID(w http.ResponseWriter, r *http.Request) (int32, bool) {
	id, err := strconv.ParseInt(chi.URLParam(r, "contact_id"), 10, 32)
	if err != nil {
		notFoundJSON(w)
		return 0, false
	}
	return int32(id), true
}

// contactError é o modelError com o RecordInvalid do Rails ({message, attributes}).
func contactError(w http.ResponseWriter, err error) {
	var invalid *models.ValidationError
	if errors.As(err, &invalid) {
		views.JSON(w, http.StatusUnprocessableEntity, views.RecordInvalid(invalid))
		return
	}
	modelError(w, err)
}

// optionalString lê um campo que pode faltar (nil) ou vir null (texto vazio), como o permit do Rails.
func optionalString(raw map[string]json.RawMessage, key string) (*string, bool) {
	v, ok := raw[key]
	if !ok {
		return nil, true
	}
	var s *string
	if err := json.Unmarshal(v, &s); err != nil {
		return nil, false
	}
	if s == nil {
		empty := ""
		return &empty, true
	}
	return s, true
}

// Update é o update do ContactsController (ContactPolicy#update? libera qualquer membro).
func (c Contacts) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	var raw map[string]json.RawMessage
	if !decode(w, r, &raw) {
		return
	}
	var in models.ContactUpdate
	for key, field := range map[string]**string{
		"name": &in.Name, "identifier": &in.Identifier, "email": &in.Email, "phone_number": &in.PhoneNumber,
	} {
		v, valid := optionalString(raw, key)
		if !valid {
			views.JSON(w, http.StatusBadRequest, views.Error("Invalid JSON body"))
			return
		}
		*field = v
	}
	if v, ok := raw["blocked"]; ok {
		var blocked bool
		if json.Unmarshal(v, &blocked) == nil {
			in.Blocked = &blocked
		}
	}
	for key, into := range map[string]*map[string]any{
		"additional_attributes": &in.AdditionalAttributes, "custom_attributes": &in.CustomAttributes,
	} {
		if v, ok := raw[key]; ok {
			_ = json.Unmarshal(v, into) // não sendo objeto, o permit do Rails descarta
		}
	}
	contact, err := c.Contacts.Update(r.Context(), CurrentMembership(r).AccountID, id, in)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.ContactShow(contact))
}

// Destroy é o destroy: só administrador (ContactPolicy#destroy?).
func (c Contacts) Destroy(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	if !CurrentMembership(r).Administrator() {
		unauthorized(w)
		return
	}
	if err := c.Contacts.Delete(r.Context(), CurrentMembership(r).AccountID, id); err != nil {
		contactError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}

// Labels é o contacts/labels#index.
func (c Contacts) Labels(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	labels, err := c.Contacts.Labels(r.Context(), CurrentMembership(r).AccountID, id)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.LabelsPayload(labels))
}

// SetLabels é o contacts/labels#create: {labels: [...]} substitui a lista.
func (c Contacts) SetLabels(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	var in struct {
		Labels []string `json:"labels"`
	}
	if !decode(w, r, &in) {
		return
	}
	labels, err := c.Contacts.SetLabels(r.Context(), CurrentMembership(r).AccountID, id, in.Labels)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.LabelsPayload(labels))
}

// ContactConversations é o contacts/conversations#index (sem o modo `conversation_id` com as vizinhas).
type ContactConversations struct {
	Conversations *models.Conversations
}

func (c ContactConversations) Index(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	user := CurrentUser(r).ID
	var only *int32
	if !CurrentMembership(r).Administrator() {
		only = &user
	}
	items, err := c.Conversations.ForContact(r.Context(), CurrentMembership(r).AccountID, id, user, only)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.ContactConversations(items))
}

// ContactNotes é o contacts/notes_controller.rb; qualquer membro da conta usa todas as ações.
type ContactNotes struct {
	Notes *models.ContactNotes
}

func noteID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(chi.URLParam(r, "note_id"), 10, 64)
	if err != nil {
		notFoundJSON(w)
		return 0, false
	}
	return id, true
}

// noteContent é o params.require(:note).permit(:content). O ParamsWrapper do Rails embrulha o `content` enviado
// na raiz em `note` (é assim que o dashboard do Chatwoot manda); sem nenhum dos dois, o ParameterMissing vira 422.
func noteContent(w http.ResponseWriter, r *http.Request) (string, bool) {
	var in struct {
		Content *string `json:"content"`
		Note    *struct {
			Content string `json:"content"`
		} `json:"note"`
	}
	if !decode(w, r, &in) {
		return "", false
	}
	switch {
	case in.Note != nil:
		return in.Note.Content, true
	case in.Content != nil:
		return *in.Content, true
	}
	views.JSON(w, http.StatusUnprocessableEntity, views.Error("param is missing or the value is empty: note"))
	return "", false
}

func (c ContactNotes) Index(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	notes, err := c.Notes.List(r.Context(), CurrentMembership(r).AccountID, id)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Notes(notes))
}

func (c ContactNotes) Show(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	nid, ok := noteID(w, r)
	if !ok {
		return
	}
	note, err := c.Notes.Get(r.Context(), CurrentMembership(r).AccountID, id, nid)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Note(note))
}

func (c ContactNotes) Create(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	content, ok := noteContent(w, r)
	if !ok {
		return
	}
	note, err := c.Notes.Create(r.Context(), CurrentMembership(r).AccountID, id, CurrentUser(r).ID, content)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Note(note))
}

func (c ContactNotes) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	nid, ok := noteID(w, r)
	if !ok {
		return
	}
	content, ok := noteContent(w, r)
	if !ok {
		return
	}
	note, err := c.Notes.Update(r.Context(), CurrentMembership(r).AccountID, id, nid, CurrentUser(r).ID, content)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Note(note))
}

func (c ContactNotes) Destroy(w http.ResponseWriter, r *http.Request) {
	id, ok := contactID(w, r)
	if !ok {
		return
	}
	nid, ok := noteID(w, r)
	if !ok {
		return
	}
	if err := c.Notes.Delete(r.Context(), CurrentMembership(r).AccountID, id, nid); err != nil {
		contactError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}
