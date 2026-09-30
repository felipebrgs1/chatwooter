package controllers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
	"github.com/go-chi/chi/v5"
)

// Companies porta CompaniesController; CompanyPolicy permite leitura/criação a qualquer membro.
// No v1 empresas ficam disponíveis em todas as contas (feature habilitada por padrão no Chatwoot);
// o gate por feature_flags fica para a configuração de recursos da conta.
type Companies struct{ Companies *models.Companies }

func (c Companies) Index(w http.ResponseWriter, r *http.Request)  { c.list(w, r, false) }
func (c Companies) Search(w http.ResponseWriter, r *http.Request) { c.list(w, r, true) }
func (c Companies) list(w http.ResponseWriter, r *http.Request, search bool) {
	q := models.CompanyQuery{Sort: r.URL.Query().Get("sort")}
	var page any = 1
	if raw := r.URL.Query().Get("page"); raw != "" {
		page = raw
		q.Page, _ = strconv.Atoi(raw)
	}
	if search {
		q.Search = r.URL.Query().Get("q")
		if strings.TrimSpace(q.Search) == "" {
			views.JSON(w, http.StatusUnprocessableEntity, views.Error("Specify search string with parameter q"))
			return
		}
	}
	out, err := c.Companies.List(r.Context(), CurrentMembership(r).AccountID, q)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.CompaniesPage(out, page))
}

func (c Companies) Show(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "company_id"), 10, 64)
	if err != nil {
		notFoundJSON(w)
		return
	}
	company, err := c.Companies.Get(r.Context(), CurrentMembership(r).AccountID, id)
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.CompanyShow(company))
}

func (c Companies) Create(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Company *models.CompanyInput `json:"company"`
	}
	if !decode(w, r, &input) {
		return
	}
	if input.Company == nil {
		views.JSON(w, http.StatusBadRequest, views.Error("param is missing or the value is empty: company"))
		return
	}
	company, err := c.Companies.Create(r.Context(), CurrentMembership(r).AccountID, *input.Company)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.CompanyShow(company))
}

func (c Companies) Update(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/form-data") {
		c.UploadAvatar(w, r)
		return
	}
	id, err := strconv.ParseInt(chi.URLParam(r, "company_id"), 10, 64)
	if err != nil {
		notFoundJSON(w)
		return
	}
	var input struct {
		Company map[string]json.RawMessage `json:"company"`
	}
	if !decode(w, r, &input) {
		return
	}
	if len(input.Company) == 0 {
		views.JSON(w, http.StatusBadRequest, views.Error("param is missing or the value is empty: company"))
		return
	}
	company, err := c.Companies.Update(r.Context(), CurrentMembership(r).AccountID, id, input.Company)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.CompanyShow(company))
}

func (c Companies) Destroy(w http.ResponseWriter, r *http.Request) {
	if !CurrentMembership(r).Administrator() {
		unauthorized(w)
		return
	}
	id, err := strconv.ParseInt(chi.URLParam(r, "company_id"), 10, 64)
	if err != nil {
		notFoundJSON(w)
		return
	}
	if err := c.Companies.Delete(r.Context(), CurrentMembership(r).AccountID, id); err != nil {
		contactError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}
