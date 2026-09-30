package models

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
)

type Company struct {
	ID                   int64
	Name                 string
	Domain, Description  *string
	ContactsCount        *int32
	CustomAttributes     json.RawMessage
	CreatedAt, UpdatedAt time.Time
	LastActivityAt       *time.Time
}

type CompanyInput struct {
	Name                 string         `json:"name"`
	Domain               *string        `json:"domain"`
	Description          *string        `json:"description"`
	AdditionalAttributes map[string]any `json:"additional_attributes"`
	CustomAttributes     map[string]any `json:"custom_attributes"`
}

type CompanyQuery struct {
	Page         int
	Sort, Search string
}
type CompanyPage struct {
	Companies  []Company
	TotalCount int64
}
type Companies struct{ q *sqlc.Queries }

func NewCompanies(db sqlc.DBTX) *Companies { return &Companies{q: sqlc.New(db)} }

func companyFromRow(r sqlc.Company) Company {
	var count *int32
	if r.ContactsCount.Valid {
		count = &r.ContactsCount.Int32
	}
	return Company{
		ID: r.ID, Name: r.Name, Domain: textPtr(r.Domain), Description: textPtr(r.Description), ContactsCount: count,
		CustomAttributes: orEmptyObject(r.CustomAttributes), CreatedAt: r.CreatedAt, UpdatedAt: r.UpdatedAt, LastActivityAt: r.LastActivityAt,
	}
}

func (c *Companies) List(ctx context.Context, accountID int32, in CompanyQuery) (CompanyPage, error) {
	sort := strings.TrimPrefix(in.Sort, "-")
	switch sort {
	case "name", "domain", "created_at", "last_activity_at", "contacts_count":
	default:
		in.Sort = "name"
	}
	if in.Page < 1 || in.Page > math.MaxInt32/25 {
		in.Page = 1
	}
	offset := int64(in.Page-1) * 25
	if offset < 0 || offset > math.MaxInt32 {
		offset = 0
	}
	term := strings.TrimSpace(in.Search)
	count, err := c.q.CountCompanies(ctx, sqlc.CountCompaniesParams{AccountID: int64(accountID), Search: term})
	if err != nil {
		return CompanyPage{}, err
	}
	rows, err := c.q.ListCompanies(ctx, sqlc.ListCompaniesParams{AccountID: int64(accountID), Search: term, Sort: in.Sort, PageLimit: 25, PageOffset: int32(offset)})
	if err != nil {
		return CompanyPage{}, err
	}
	out := CompanyPage{Companies: make([]Company, 0, len(rows)), TotalCount: count}
	for _, r := range rows {
		out.Companies = append(out.Companies, companyFromRow(r))
	}
	return out, nil
}

func (c *Companies) Get(ctx context.Context, accountID int32, id int64) (Company, error) {
	r, err := c.q.GetCompany(ctx, sqlc.GetCompanyParams{AccountID: int64(accountID), ID: id})
	if err != nil {
		return Company{}, notFound(err)
	}
	return companyFromRow(r), nil
}

var companyDomain = regexp.MustCompile(`\A[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+\z`)

func (c *Companies) Create(ctx context.Context, accountID int32, in CompanyInput) (Company, error) {
	invalid := &ValidationError{}
	if strings.TrimSpace(in.Name) == "" {
		invalid.add("name", "Name can't be blank")
	}
	if utf8.RuneCountInString(in.Name) > 100 {
		invalid.add("name", "Name is too long (maximum is 100 characters)")
	}
	if in.Domain != nil && *in.Domain != "" && !companyDomain.MatchString(*in.Domain) {
		invalid.add("domain", "Domain is invalid")
	}
	if in.Description != nil && utf8.RuneCountInString(*in.Description) > 1000 {
		invalid.add("description", "Description is too long (maximum is 1000 characters)")
	}
	if len(invalid.Messages) > 0 {
		return Company{}, invalid
	}
	if in.AdditionalAttributes == nil {
		in.AdditionalAttributes = map[string]any{}
	}
	if in.CustomAttributes == nil {
		in.CustomAttributes = map[string]any{}
	}
	additional, _ := json.Marshal(in.AdditionalAttributes)
	custom, _ := json.Marshal(in.CustomAttributes)
	r, err := c.q.CreateCompany(ctx, sqlc.CreateCompanyParams{AccountID: int64(accountID), Name: in.Name, Domain: companyText(in.Domain), Description: companyText(in.Description), AdditionalAttributes: orEmptyObject(additional), CustomAttributes: orEmptyObject(custom)})
	var constraint *pgconn.PgError
	if errors.As(err, &constraint) && constraint.Code == "23505" {
		invalid.add("domain", "Domain has already been taken")
		return Company{}, invalid
	}
	if err != nil {
		return Company{}, err
	}
	// Favicon e sincronização de contatos serão jobs River quando avatar/vínculos forem portados.
	return companyFromRow(r), nil
}

func companyText(value *string) pgtype.Text {
	if value == nil {
		return pgtype.Text{}
	}
	return pgtype.Text{String: *value, Valid: true}
}
