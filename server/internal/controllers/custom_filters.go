package controllers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// CustomFilters porta CustomFiltersController: as pastas são do usuário logado (CustomFilterPolicy libera a
// qualquer membro), e a de outro usuário responde 404, como o find escopado do Chatwoot.
type CustomFilters struct{ CustomFilters *models.CustomFilters }

func (c CustomFilters) Index(w http.ResponseWriter, r *http.Request) {
	out, err := c.CustomFilters.List(r.Context(), CurrentMembership(r).AccountID, CurrentUser(r).ID, r.URL.Query().Get("filter_type"))
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.CustomFilters(out))
}

func (c CustomFilters) Show(w http.ResponseWriter, r *http.Request) {
	id, ok := customFilterID(w, r)
	if !ok {
		return
	}
	f, err := c.CustomFilters.Get(r.Context(), CurrentMembership(r).AccountID, CurrentUser(r).ID, id)
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.CustomFilter(f))
}

func (c CustomFilters) Create(w http.ResponseWriter, r *http.Request) {
	in, ok := customFilterInput(w, r)
	if !ok {
		return
	}
	f, err := c.CustomFilters.Create(r.Context(), CurrentMembership(r).AccountID, CurrentUser(r).ID, in)
	if err != nil {
		customFilterError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.CustomFilter(f))
}

func (c CustomFilters) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := customFilterID(w, r)
	if !ok {
		return
	}
	in, ok := customFilterInput(w, r)
	if !ok {
		return
	}
	f, err := c.CustomFilters.Update(r.Context(), CurrentMembership(r).AccountID, CurrentUser(r).ID, id, in)
	if err != nil {
		customFilterError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.CustomFilter(f))
}

func (c CustomFilters) Destroy(w http.ResponseWriter, r *http.Request) {
	id, ok := customFilterID(w, r)
	if !ok {
		return
	}
	if err := c.CustomFilters.Delete(r.Context(), CurrentMembership(r).AccountID, CurrentUser(r).ID, id); err != nil {
		modelError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func customFilterID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		notFoundJSON(w)
		return 0, false
	}
	return id, true
}

func customFilterInput(w http.ResponseWriter, r *http.Request) (models.CustomFilterInput, bool) {
	var body struct {
		CustomFilter *models.CustomFilterInput `json:"custom_filter"`
	}
	if !decode(w, r, &body) {
		return models.CustomFilterInput{}, false
	}
	if body.CustomFilter == nil {
		views.JSON(w, http.StatusBadRequest, views.Error("param is missing or the value is empty: custom_filter"))
		return models.CustomFilterInput{}, false
	}
	return *body.CustomFilter, true
}

// customFilterError: fuso/payload inválido é o render_could_not_create_error ({error}); limite é record invalid.
func customFilterError(w http.ResponseWriter, err error) {
	var invalid models.FilterError
	if errors.As(err, &invalid) {
		views.JSON(w, http.StatusUnprocessableEntity, views.Error(invalid.Message))
		return
	}
	contactError(w, err)
}
