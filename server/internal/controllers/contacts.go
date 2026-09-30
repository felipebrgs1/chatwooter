package controllers

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// Contacts é a leitura do api/v1/accounts/contacts_controller.rb (index, search, show).
// ContactPolicy libera essas ações para qualquer membro da conta.
type Contacts struct {
	Contacts *models.Contacts
}

// contactQuery lê sort, page, labels[] e include_contact_inboxes; currentPage é o `params[:page] || 1` do meta.
func contactQuery(r *http.Request) (models.ContactQuery, any) {
	params := r.URL.Query()
	q := models.ContactQuery{Sort: params.Get("sort"), Labels: params["labels[]"], WithInboxes: includeContactInboxes(r)}
	var currentPage any = 1
	if raw := params.Get("page"); raw != "" {
		currentPage = raw
		q.Page, _ = strconv.Atoi(raw) // inválido vira página 1, como no Kaminari
	}
	return q, currentPage
}

// includeContactInboxes é o set_include_contact_inboxes: ausente = true; presente, só "true" inclui.
func includeContactInboxes(r *http.Request) bool {
	params := r.URL.Query()
	if !params.Has("include_contact_inboxes") || params.Get("include_contact_inboxes") == "" {
		return true
	}
	return params.Get("include_contact_inboxes") == "true"
}

func (c Contacts) Index(w http.ResponseWriter, r *http.Request) {
	q, currentPage := contactQuery(r)
	page, err := c.Contacts.List(r.Context(), CurrentMembership(r).AccountID, q)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.ContactsPage(page, currentPage, false))
}

func (c Contacts) Search(w http.ResponseWriter, r *http.Request) {
	term := r.URL.Query().Get("q")
	if strings.TrimSpace(term) == "" {
		views.JSON(w, http.StatusUnprocessableEntity, views.Error("Specify search string with parameter q"))
		return
	}
	q, currentPage := contactQuery(r)
	page, err := c.Contacts.Search(r.Context(), CurrentMembership(r).AccountID, term, q)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.ContactsPage(page, currentPage, true))
}

func (c Contacts) Show(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "contact_id"), 10, 32)
	if err != nil {
		notFoundJSON(w)
		return
	}
	contact, err := c.Contacts.Get(r.Context(), CurrentMembership(r).AccountID, int32(id), includeContactInboxes(r))
	switch {
	case errors.Is(err, models.ErrNotFound):
		notFoundJSON(w)
	case err != nil:
		serverError(w, err)
	default:
		views.JSON(w, http.StatusOK, views.ContactShow(contact))
	}
}
