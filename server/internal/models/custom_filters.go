package models

import (
	"context"
	"encoding/json"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

// CustomFilters são as pastas (filtros salvos) de cada usuário na conta: CustomFilter do Chatwoot.
type CustomFilters struct{ q *sqlc.Queries }

func NewCustomFilters(db sqlc.DBTX) *CustomFilters { return &CustomFilters{q: sqlc.New(db)} }

type CustomFilter struct {
	ID         int64
	Name       string
	FilterType string
	Query      json.RawMessage
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

// CustomFilterInput: campo nil não muda (update) ou fica no padrão do banco (create).
type CustomFilterInput struct {
	Name *string `json:"name"`
	// FilterType aceita o nome ("conversation") ou o número do enum (0), como o Rails.
	FilterType json.RawMessage `json:"filter_type"`
	Query      json.RawMessage `json:"query"`
}

// enum filter_type do CustomFilter.
var customFilterTypes = map[string]int32{"conversation": 0, "contact": 1, "report": 2}

// Limits::MAX_CUSTOM_FILTERS_PER_USER.
const maxCustomFiltersPerUser = 1000

func customFilterFrom(r sqlc.CustomFilter) CustomFilter {
	name := "conversation"
	for k, v := range customFilterTypes {
		if v == r.FilterType {
			name = k
		}
	}
	return CustomFilter{ID: r.ID, Name: r.Name, FilterType: name, Query: r.Query, CreatedAt: r.CreatedAt, UpdatedAt: r.UpdatedAt}
}

// List devolve as pastas do usuário de um tipo (conversation quando vazio), na ordem em que foram criadas.
func (c *CustomFilters) List(ctx context.Context, accountID, userID int32, filterType string) ([]CustomFilter, error) {
	if filterType == "" {
		filterType = "conversation"
	}
	out := []CustomFilter{}
	kind, ok := customFilterTypes[filterType]
	if !ok {
		return out, nil
	}
	rows, err := c.q.ListCustomFilters(ctx, sqlc.ListCustomFiltersParams{AccountID: int64(accountID), UserID: int64(userID), FilterType: kind})
	if err != nil {
		return nil, err
	}
	for _, r := range rows {
		out = append(out, customFilterFrom(r))
	}
	return out, nil
}

func (c *CustomFilters) Get(ctx context.Context, accountID, userID int32, id int64) (CustomFilter, error) {
	r, err := c.q.GetCustomFilter(ctx, sqlc.GetCustomFilterParams{AccountID: int64(accountID), UserID: int64(userID), ID: id})
	if err != nil {
		return CustomFilter{}, notFound(err)
	}
	return customFilterFrom(r), nil
}

func (c *CustomFilters) Create(ctx context.Context, accountID, userID int32, in CustomFilterInput) (CustomFilter, error) {
	if err := validateFilterQuery(in.Query); err != nil {
		return CustomFilter{}, err
	}
	if in.Name == nil || *in.Name == "" {
		return CustomFilter{}, ErrInvalid
	}
	kind, err := filterTypeValue(in.FilterType, 0)
	if err != nil {
		return CustomFilter{}, err
	}
	total, err := c.q.CountCustomFiltersOfUser(ctx, sqlc.CountCustomFiltersOfUserParams{AccountID: int64(accountID), UserID: int64(userID)})
	if err != nil {
		return CustomFilter{}, err
	}
	if total >= maxCustomFiltersPerUser {
		invalid := &ValidationError{}
		invalid.add("account_id", "Account Limit reached. The maximum number of allowed custom filters for a user per account is 1000.")
		return CustomFilter{}, invalid
	}
	query := []byte(in.Query)
	if len(query) == 0 {
		query = []byte("{}")
	}
	r, err := c.q.CreateCustomFilter(ctx, sqlc.CreateCustomFilterParams{
		AccountID: int64(accountID), UserID: int64(userID), Name: *in.Name, FilterType: kind, Query: query,
	})
	if err != nil {
		return CustomFilter{}, err
	}
	return customFilterFrom(r), nil
}

func (c *CustomFilters) Update(ctx context.Context, accountID, userID int32, id int64, in CustomFilterInput) (CustomFilter, error) {
	current, err := c.q.GetCustomFilter(ctx, sqlc.GetCustomFilterParams{AccountID: int64(accountID), UserID: int64(userID), ID: id})
	if err != nil {
		return CustomFilter{}, notFound(err)
	}
	if err := validateFilterQuery(in.Query); err != nil {
		return CustomFilter{}, err
	}
	params := sqlc.UpdateCustomFilterParams{
		AccountID: int64(accountID), UserID: int64(userID), ID: id,
		Name: current.Name, FilterType: current.FilterType, Query: current.Query,
	}
	if in.Name != nil {
		if *in.Name == "" {
			return CustomFilter{}, ErrInvalid
		}
		params.Name = *in.Name
	}
	if params.FilterType, err = filterTypeValue(in.FilterType, current.FilterType); err != nil {
		return CustomFilter{}, err
	}
	if len(in.Query) > 0 {
		params.Query = in.Query
	}
	r, err := c.q.UpdateCustomFilter(ctx, params)
	if err != nil {
		return CustomFilter{}, err
	}
	return customFilterFrom(r), nil
}

func (c *CustomFilters) Delete(ctx context.Context, accountID, userID int32, id int64) error {
	n, err := c.q.DeleteCustomFilter(ctx, sqlc.DeleteCustomFilterParams{AccountID: int64(accountID), UserID: int64(userID), ID: id})
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func filterTypeValue(raw json.RawMessage, fallback int32) (int32, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return fallback, nil
	}
	var number int32
	if err := json.Unmarshal(raw, &number); err == nil {
		for _, v := range customFilterTypes {
			if v == number {
				return number, nil
			}
		}
		return 0, ErrInvalid
	}
	var name string
	if err := json.Unmarshal(raw, &name); err != nil {
		return 0, ErrInvalid
	}
	kind, ok := customFilterTypes[name]
	if !ok {
		return 0, ErrInvalid
	}
	return kind, nil
}

// validateFilterQuery é o validate_query_timezones do controller: payload tem de ser lista de condições,
// e um timezone informado tem de ser um fuso válido.
func validateFilterQuery(raw json.RawMessage) error {
	if len(raw) == 0 || string(raw) == "null" {
		return nil
	}
	var query map[string]json.RawMessage
	if err := json.Unmarshal(raw, &query); err != nil {
		return ErrInvalid
	}
	payload, ok := query["payload"]
	if !ok {
		return nil
	}
	var conditions []map[string]json.RawMessage
	if err := json.Unmarshal(payload, &conditions); err != nil {
		return invalidValue("payload")
	}
	for _, cond := range conditions {
		if cond == nil {
			return invalidValue("payload")
		}
		if tz, ok := cond["timezone"]; ok {
			var name string
			if err := json.Unmarshal(tz, &name); err != nil || name == "" {
				return invalidValue("timezone")
			}
			if _, err := time.LoadLocation(name); err != nil {
				return invalidValue("timezone")
			}
		}
	}
	return nil
}
