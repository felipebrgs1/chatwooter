package views

import (
	"encoding/json"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

// CompanyResponse espelha api/v1/models/_company.json.jbuilder.
type CompanyResponse struct {
	ID               int64           `json:"id"`
	Name             string          `json:"name"`
	Domain           *string         `json:"domain"`
	Description      *string         `json:"description"`
	ContactsCount    *int32          `json:"contacts_count"`
	CustomAttributes json.RawMessage `json:"custom_attributes"`
	AvatarURL        string          `json:"avatar_url"`
	LastActivityAt   *int64          `json:"last_activity_at,omitempty"`
	CreatedAt        int64           `json:"created_at"`
	UpdatedAt        int64           `json:"updated_at"`
}

func Company(c models.Company) CompanyResponse {
	var activity *int64
	if c.LastActivityAt != nil {
		v := c.LastActivityAt.Unix()
		activity = &v
	}
	return CompanyResponse{ID: c.ID, Name: c.Name, Domain: c.Domain, Description: c.Description, ContactsCount: c.ContactsCount, CustomAttributes: c.CustomAttributes, AvatarURL: c.AvatarURL, LastActivityAt: activity, CreatedAt: c.CreatedAt.Unix(), UpdatedAt: c.UpdatedAt.Unix()}
}

// CompaniesPage espelha api/v1/accounts/companies/index.json.jbuilder e search.json.jbuilder.
func CompaniesPage(p models.CompanyPage, page any) any {
	payload := make([]CompanyResponse, 0, len(p.Companies))
	for _, c := range p.Companies {
		payload = append(payload, Company(c))
	}
	return struct {
		Meta    any               `json:"meta"`
		Payload []CompanyResponse `json:"payload"`
	}{
		Meta: struct {
			TotalCount int64 `json:"total_count"`
			Page       any   `json:"page"`
		}{p.TotalCount, page}, Payload: payload,
	}
}

// CompanyShow espelha api/v1/accounts/companies/{show,create}.json.jbuilder.
func CompanyShow(c models.Company) any {
	return struct {
		Payload CompanyResponse `json:"payload"`
	}{Company(c)}
}
