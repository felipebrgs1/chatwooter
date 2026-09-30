package models

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"os"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
)

type Company struct {
	AvatarURL            string
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
type Companies struct {
	q          *sqlc.Queries
	db         DB
	uploadsDir string
}

func NewCompanies(db DB, directories ...string) *Companies {
	directory := "./storage"
	if len(directories) > 0 {
		directory = directories[0]
	}
	return &Companies{q: sqlc.New(db), db: db, uploadsDir: directory}
}

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
		company := companyFromRow(r)
		company.AvatarURL, err = c.avatarURL(ctx, accountID, r.ID)
		if err != nil {
			return CompanyPage{}, err
		}
		out.Companies = append(out.Companies, company)
	}
	return out, nil
}

func (c *Companies) Get(ctx context.Context, accountID int32, id int64) (Company, error) {
	r, err := c.q.GetCompany(ctx, sqlc.GetCompanyParams{AccountID: int64(accountID), ID: id})
	if err != nil {
		return Company{}, notFound(err)
	}
	company := companyFromRow(r)
	company.AvatarURL, err = c.avatarURL(ctx, accountID, id)
	return company, err
}

var companyDomain = regexp.MustCompile(`\A[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+\z`)

func (c *Companies) Create(ctx context.Context, accountID int32, in CompanyInput) (Company, error) {
	if err := validateCompany(in); err != nil {
		return Company{}, err
	}
	invalid := &ValidationError{}
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

func validateCompany(in CompanyInput) error {
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
		return invalid
	}
	return nil
}

// Update keeps omitted fields and merges custom attributes like company_update_params.
func (c *Companies) Update(ctx context.Context, accountID int32, id int64, fields map[string]json.RawMessage) (Company, error) {
	var saved Company
	err := withTx(ctx, c.db, func(tx pgx.Tx) error {
		q := sqlc.New(tx)
		current, err := q.LockCompany(ctx, sqlc.LockCompanyParams{AccountID: int64(accountID), ID: id})
		if err != nil {
			return notFound(err)
		}
		in := CompanyInput{Name: current.Name, Domain: textPtr(current.Domain), Description: textPtr(current.Description)}
		for key, into := range map[string]any{"name": &in.Name, "domain": &in.Domain, "description": &in.Description} {
			if raw, ok := fields[key]; ok {
				if key == "name" && string(raw) == "null" {
					in.Name = ""
					continue
				}
				if err := json.Unmarshal(raw, into); err != nil {
					return &ValidationError{Messages: []string{"Invalid company field"}}
				}
			}
		}
		if err := validateCompany(in); err != nil {
			return err
		}
		additional := orEmptyObject(current.AdditionalAttributes)
		custom := map[string]any{}
		if err := json.Unmarshal(orEmptyObject(current.CustomAttributes), &custom); err != nil {
			return err
		}
		if raw, ok := fields["custom_attributes"]; ok {
			var changes map[string]any
			if err := json.Unmarshal(raw, &changes); err != nil {
				return err
			}
			for key, value := range changes {
				custom[key] = value
			}
		}
		if raw, ok := fields["additional_attributes"]; ok {
			var attrs map[string]any
			if err := json.Unmarshal(raw, &attrs); err != nil {
				return err
			}
			additional, err = json.Marshal(attrs)
			if err != nil {
				return err
			}
		}
		customJSON, err := json.Marshal(custom)
		if err != nil {
			return err
		}
		row, err := q.UpdateCompany(ctx, sqlc.UpdateCompanyParams{AccountID: int64(accountID), ID: id, Name: in.Name, Domain: companyText(in.Domain), Description: companyText(in.Description), AdditionalAttributes: orEmptyObject(additional), CustomAttributes: customJSON})
		if err != nil {
			var constraint *pgconn.PgError
			if errors.As(err, &constraint) && constraint.Code == "23505" {
				invalid := &ValidationError{}
				invalid.add("domain", "Domain has already been taken")
				return invalid
			}
			return err
		}
		// v1 has no contact callbacks; keep the local name sync atomic instead of queuing a separate job.
		if current.Name != in.Name {
			if err := q.SyncCompanyContactNames(ctx, sqlc.SyncCompanyContactNamesParams{AccountID: int32(accountID), CompanyID: pgtype.Int8{Int64: id, Valid: true}, CompanyName: in.Name}); err != nil {
				return err
			}
		}
		saved = companyFromRow(row)
		return nil
	})
	if err != nil {
		return saved, err
	}
	return c.Get(ctx, accountID, id)
}

// Delete mirrors Companies::DeleteJob, preserving contacts and removing the local avatar.
func (c *Companies) Delete(ctx context.Context, accountID int32, id int64) error {
	var avatar sqlc.ActiveStorageBlob
	var avatarErr error
	err := withTx(ctx, c.db, func(tx pgx.Tx) error {
		q := sqlc.New(tx)
		if _, err := q.LockCompany(ctx, sqlc.LockCompanyParams{AccountID: int64(accountID), ID: id}); err != nil {
			return notFound(err)
		}
		avatar, avatarErr = q.CompanyAvatar(ctx, sqlc.CompanyAvatarParams{AccountID: int64(accountID), ID: id})
		if avatarErr != nil && !errors.Is(avatarErr, pgx.ErrNoRows) {
			return avatarErr
		}
		if err := q.DetachCompanyAvatar(ctx, id); err != nil {
			return err
		}
		if avatarErr == nil {
			if err := q.DeleteAvatarBlob(ctx, avatar.ID); err != nil {
				return err
			}
		}
		if err := q.UnlinkCompanyContacts(ctx, sqlc.UnlinkCompanyContactsParams{AccountID: accountID, CompanyID: pgtype.Int8{Int64: id, Valid: true}}); err != nil {
			return err
		}
		return q.DeleteCompany(ctx, sqlc.DeleteCompanyParams{AccountID: int64(accountID), ID: id})
	})
	if err == nil && avatarErr == nil {
		if path, e := c.avatarPath(avatar.Key); e == nil {
			_ = os.Remove(path)
		}
	}
	return err
}
