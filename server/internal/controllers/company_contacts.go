package controllers

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/felipeborgaco/chatwooter/server/internal/views"
	"github.com/go-chi/chi/v5"
)

func (c Companies) companyID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(chi.URLParam(r, "company_id"), 10, 64)
	if err != nil {
		notFoundJSON(w)
		return 0, false
	}
	if _, err := c.Companies.Get(r.Context(), CurrentMembership(r).AccountID, id); err != nil {
		modelError(w, err)
		return 0, false
	}
	return id, true
}

func (c Companies) Contacts(w http.ResponseWriter, r *http.Request)       { c.contacts(w, r, false) }
func (c Companies) SearchContacts(w http.ResponseWriter, r *http.Request) { c.contacts(w, r, true) }
func (c Companies) contacts(w http.ResponseWriter, r *http.Request, searching bool) {
	id, ok := c.companyID(w, r)
	if !ok {
		return
	}
	page := r.URL.Query().Get("page")
	if page == "" {
		page = "1"
	}
	number, _ := strconv.Atoi(page)
	term := r.URL.Query().Get("q")
	if searching && strings.TrimSpace(term) == "" {
		views.JSON(w, 422, views.Error("Specify search string with parameter q"))
		return
	}
	out, err := c.Companies.Contacts(r.Context(), CurrentMembership(r).AccountID, id, number, term, searching)
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, 200, views.CompanyContacts(out, page))
}

func (c Companies) LinkContact(w http.ResponseWriter, r *http.Request) {
	id, ok := c.companyID(w, r)
	if !ok {
		return
	}
	var input struct {
		ID int32 `json:"contact_id"`
	}
	if !decode(w, r, &input) {
		return
	}
	account := CurrentMembership(r).AccountID
	if err := c.Companies.Membership(r.Context(), account, input.ID, &id, nil); err != nil {
		contactError(w, err)
		return
	}
	contact, err := c.Companies.Contact(r.Context(), account, input.ID, id)
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, 200, map[string]any{"payload": views.CompanyContact(contact)})
}

func (c Companies) UnlinkContact(w http.ResponseWriter, r *http.Request) {
	id, ok := c.companyID(w, r)
	if !ok {
		return
	}
	contactID, err := strconv.ParseInt(chi.URLParam(r, "contact_id"), 10, 32)
	if err != nil {
		notFoundJSON(w)
		return
	}
	if err := c.Companies.Membership(r.Context(), CurrentMembership(r).AccountID, int32(contactID), nil, &id); err != nil {
		modelError(w, err)
		return
	}
	w.WriteHeader(200)
}

func (c Companies) Notes(w http.ResponseWriter, r *http.Request) {
	id, ok := c.companyID(w, r)
	if !ok {
		return
	}
	notes, err := c.Companies.Notes(r.Context(), CurrentMembership(r).AccountID, id)
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, 200, views.CompanyNotes(notes))
}

func (c Companies) Conversations(w http.ResponseWriter, r *http.Request) {
	id, ok := c.companyID(w, r)
	if !ok {
		return
	}
	m := CurrentMembership(r)
	items, err := c.Companies.Conversations(r.Context(), m.AccountID, CurrentUser(r).ID, id, m.Administrator())
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, 200, views.ContactConversations(items))
}
