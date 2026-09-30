package models

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"slices"
	"strconv"
	"strings"
	"time"
	// O filtro por data usa fusos IANA; a imagem de produção pode não ter o zoneinfo do sistema.
	_ "time/tzdata"
)

// FilterCondition é um item do payload de POST /conversations/filter (e da query de uma pasta).
type FilterCondition struct {
	AttributeKey        string          `json:"attribute_key"`
	FilterOperator      string          `json:"filter_operator"`
	Values              json.RawMessage `json:"values"`
	QueryOperator       *string         `json:"query_operator"`
	CustomAttributeType string          `json:"custom_attribute_type"`
	// Timezone presente (mesmo nulo) liga o filtro por fuso nas datas: o Chatwoot testa a chave, não o valor.
	Timezone json.RawMessage `json:"timezone"`
}

// FilterError são os CustomExceptions::CustomFilter do Chatwoot: viram 422 com a mensagem no corpo.
type FilterError struct{ Message string }

func (e FilterError) Error() string { return e.Message }

func invalidAttribute(key string) error {
	return FilterError{fmt.Sprintf("Invalid attribute key - [%s]. The key should be one of [%s] or a custom attribute defined in the account.",
		key, strings.Join(conversationFilterKeys, ","))}
}

func invalidOperator(key string, allowed []string) error {
	return FilterError{fmt.Sprintf("Invalid operator. The allowed operators for %s are [%s].", key, strings.Join(allowed, ","))}
}

var errInvalidQueryOperator = FilterError{`Query operator must be either "AND" or "OR".`}

func invalidValue(key string) error {
	return FilterError{fmt.Sprintf("Invalid value. The values provided for %s are invalid", key)}
}

// filterAttribute é uma entrada de conversations: em lib/filters/filter_keys.yml.
type filterAttribute struct {
	additional bool   // attribute_type: additional_attributes
	dataType   string // text | number | labels | date | link
	operators  []string
}

var (
	eqNeq      = []string{"equal_to", "not_equal_to"}
	eqNeqPres  = []string{"equal_to", "not_equal_to", "is_present", "is_not_present"}
	eqNeqLike  = []string{"equal_to", "not_equal_to", "contains", "does_not_contain"}
	dateFilter = []string{"is_greater_than", "is_less_than", "days_before"}
)

// Na ordem do filter_keys.yml: é a lista que aparece na mensagem de atributo inválido.
var conversationFilterKeys = []string{
	"status", "assignee_id", "inbox_id", "team_id", "contact_id", "priority", "display_id",
	"campaign_id", "labels", "browser_language", "conversation_language", "referer", "created_at", "last_activity_at", "mail_subject",
}

var conversationFilters = map[string]filterAttribute{
	"status":                {dataType: "text", operators: eqNeq},
	"assignee_id":           {dataType: "text", operators: eqNeqPres},
	"inbox_id":              {dataType: "text", operators: eqNeqPres},
	"team_id":               {dataType: "number", operators: eqNeqPres},
	"contact_id":            {dataType: "number", operators: eqNeq},
	"priority":              {dataType: "text", operators: eqNeq},
	"display_id":            {dataType: "number", operators: eqNeqLike},
	"campaign_id":           {dataType: "number", operators: eqNeqPres},
	"labels":                {dataType: "labels", operators: eqNeqPres},
	"browser_language":      {additional: true, dataType: "text", operators: eqNeq},
	"conversation_language": {additional: true, dataType: "text", operators: eqNeq},
	"referer":               {additional: true, dataType: "link", operators: eqNeqLike},
	"created_at":            {dataType: "date", operators: dateFilter},
	"last_activity_at":      {dataType: "date", operators: dateFilter},
	"mail_subject":          {additional: true, dataType: "text", operators: eqNeqLike},
}

// Colunas inteiras: o Rails deixa o Postgres converter '1' → 1; aqui a conversão é feita antes.
var integerFilterColumns = map[string]bool{
	"assignee_id": true, "inbox_id": true, "team_id": true, "contact_id": true, "display_id": true, "campaign_id": true,
}

// FilterService::ATTRIBUTE_TYPES, indexado pelo enum attribute_display_type (text, number, currency, percent, link, date, list, checkbox).
// currency e percent não estão no mapa do Chatwoot, que acaba gerando SQL inválido (500); aqui viram numeric.
var customAttributeTypes = map[int32]string{0: "text", 1: "numeric", 2: "numeric", 3: "numeric", 4: "text", 5: "date", 6: "text", 7: "boolean"}

var customAttributeModels = map[string]int32{"": 0, "conversation_attribute": 0, "contact_attribute": 1}

// ConversationFilterQuery é o pedido de POST /conversations/filter.
type ConversationFilterQuery struct {
	UserID            int32
	OnlyInboxesOfUser int32 // ver ConversationFilter
	Payload           []FilterCondition
	SortBy            string
	Page              int
}

// Filter é o Conversations::FilterService: aplica as condições (AND/OR na ordem em que vêm), devolve a página
// e os contadores mine/unassigned/all do conjunto filtrado. Condição inválida devolve FilterError.
func (c *Conversations) Filter(ctx context.Context, accountID int32, q ConversationFilterQuery) ([]ConversationItem, ConversationCounts, error) {
	var counts ConversationCounts
	b := &filterBuilder{ctx: ctx, db: c.db, accountID: accountID, args: []any{accountID}}
	if err := validateFilterPayload(q.Payload); err != nil {
		return nil, counts, err
	}
	parts := make([]string, 0, len(q.Payload))
	for i := range q.Payload {
		part, err := b.condition(q.Payload[i])
		if err != nil {
			return nil, counts, err
		}
		parts = append(parts, part)
	}
	where := "c.account_id = $1"
	if q.OnlyInboxesOfUser != 0 {
		where += " AND c.inbox_id IN (SELECT inbox_id FROM inbox_members WHERE user_id = " + b.arg(q.OnlyInboxesOfUser) + ")"
	}
	if len(parts) > 0 {
		where += " AND (" + strings.Join(parts, " ") + ")"
	}

	countArgs := append(slices.Clone(b.args), q.UserID)
	err := c.db.QueryRow(ctx, fmt.Sprintf(`SELECT count(*) FILTER (WHERE c.assignee_id = $%d),
		count(*) FILTER (WHERE c.assignee_id IS NULL AND c.assignee_agent_bot_id IS NULL), count(*)
		FROM conversations c WHERE %s`, len(countArgs), where), countArgs...).Scan(&counts.Mine, &counts.Unassigned, &counts.All)
	if err != nil {
		return nil, counts, err
	}
	counts.Assigned = counts.All - counts.Unassigned

	page := max(q.Page, 1)
	limit, offset := b.arg(conversationsPageSize), b.arg((page-1)*conversationsPageSize)
	rows, err := c.db.Query(ctx, fmt.Sprintf(`SELECT %s FROM conversations c WHERE %s ORDER BY %s LIMIT %s OFFSET %s`,
		conversationColumns, where, orderBy(q.SortBy), limit, offset), b.args...)
	if err != nil {
		return nil, counts, err
	}
	defer rows.Close()
	var items []ConversationItem
	var links []rowLinks
	for rows.Next() {
		it, assignee, team, contact, err := scanConversation(rows)
		if err != nil {
			return nil, counts, err
		}
		items = append(items, it)
		links = append(links, rowLinks{assignee, team, contact})
	}
	if err := rows.Err(); err != nil {
		return nil, counts, err
	}
	rows.Close()
	if err := c.hydrate(ctx, accountID, q.UserID, items, links); err != nil {
		return nil, counts, err
	}
	return items, counts, nil
}

// validateFilterPayload é o validate_query_operator: roda antes de montar qualquer condição.
func validateFilterPayload(payload []FilterCondition) error {
	for i, cond := range payload {
		values, err := cond.values()
		if err != nil {
			return err
		}
		for _, v := range values {
			if _, isObject := v.(map[string]any); isObject {
				return invalidValue(cond.AttributeKey)
			}
		}
		op := cond.queryOperator()
		if op != "" && !slices.Contains([]string{"AND", "OR"}, strings.ToUpper(op)) {
			return errInvalidQueryOperator
		}
		if cond.AttributeKey == "status" || cond.AttributeKey == "priority" {
			if !cond.valuesIsArray() || !allStrings(values) {
				return invalidValue(cond.AttributeKey)
			}
		}
		if i == len(payload)-1 && op != "" {
			return errInvalidQueryOperator
		}
	}
	return nil
}

func (cond FilterCondition) queryOperator() string {
	if cond.QueryOperator == nil {
		return ""
	}
	return *cond.QueryOperator
}

func (cond FilterCondition) valuesIsArray() bool {
	return strings.HasPrefix(strings.TrimSpace(string(cond.Values)), "[")
}

// values devolve os valores como lista (um valor solto vira lista de um, como o Array.wrap do Chatwoot).
func (cond FilterCondition) values() ([]any, error) {
	if len(cond.Values) == 0 || string(cond.Values) == "null" {
		return nil, nil
	}
	var raw any
	if err := json.Unmarshal(cond.Values, &raw); err != nil {
		return nil, invalidValue(cond.AttributeKey)
	}
	if list, ok := raw.([]any); ok {
		return list, nil
	}
	return []any{raw}, nil
}

func allStrings(values []any) bool {
	for _, v := range values {
		if _, ok := v.(string); !ok {
			return false
		}
	}
	return true
}

// blank é o `values.blank?` do Rails: nada, lista vazia ou texto vazio.
func blank(values []any) bool {
	if len(values) == 0 {
		return true
	}
	if len(values) == 1 {
		if s, ok := values[0].(string); ok && strings.TrimSpace(s) == "" {
			return true
		}
	}
	return false
}

func valueString(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case float64:
		return strconv.FormatFloat(x, 'f', -1, 64)
	case bool:
		return strconv.FormatBool(x)
	case nil:
		return ""
	}
	return fmt.Sprint(v)
}

type filterBuilder struct {
	ctx       context.Context
	db        DB
	accountID int32
	args      []any
}

func (b *filterBuilder) arg(v any) string {
	b.args = append(b.args, v)
	return fmt.Sprintf("$%d", len(b.args))
}

func (b *filterBuilder) list(values []any, cast string) string {
	out := make([]string, len(values))
	for i, v := range values {
		out[i] = b.arg(v) + cast
	}
	return strings.Join(out, ", ")
}

// condition é o build_condition_query: "<expressão> <AND|OR>" de um item do payload.
func (b *filterBuilder) condition(cond FilterCondition) (string, error) {
	attr, standard := conversationFilters[cond.AttributeKey]
	if standard && !slices.Contains(attr.operators, cond.FilterOperator) {
		return "", invalidOperator(cond.AttributeKey, attr.operators)
	}
	values, _ := cond.values()
	presence := cond.FilterOperator == "is_present" || cond.FilterOperator == "is_not_present"
	if !presence && blank(values) {
		return "", invalidValue(cond.AttributeKey)
	}
	var (
		expr string
		err  error
	)
	switch {
	case !standard:
		expr, err = b.customAttribute(cond, values)
	case attr.dataType == "labels":
		expr = b.labels(cond, values)
	case attr.dataType == "date":
		expr, err = b.date(cond, values, "c."+cond.AttributeKey, true)
	case attr.additional:
		expr, err = b.compare(cond, values, "c.additional_attributes ->> "+b.arg(cond.AttributeKey), "")
	case cond.AttributeKey == "assignee_id" && presence:
		// A posse pode estar em assignee_id ou assignee_agent_bot_id (assignee_presence_filter).
		expr = "(c.assignee_id IS NULL AND c.assignee_agent_bot_id IS NULL)"
		if cond.FilterOperator == "is_present" {
			expr = "(c.assignee_id IS NOT NULL OR c.assignee_agent_bot_id IS NOT NULL)"
		}
	case cond.AttributeKey == "display_id" && (cond.FilterOperator == "contains" || cond.FilterOperator == "does_not_contain"):
		expr, err = b.compare(cond, values, "(c.display_id)::text", "")
	default:
		expr, err = b.standard(cond, values)
	}
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(expr + " " + cond.queryOperator()), nil
}

// standard trata as colunas simples, convertendo os valores conforme o tipo (enum, inteiro).
func (b *filterBuilder) standard(cond FilterCondition, values []any) (string, error) {
	key := cond.AttributeKey
	converted := make([]any, 0, len(values))
	switch {
	case key == "status":
		if slices.Contains(values, any("all")) {
			for _, v := range statusValues {
				converted = append(converted, v)
			}
			break
		}
		for _, v := range values {
			converted = append(converted, enumValue(statusValues, v))
		}
	case key == "priority":
		for _, v := range values {
			converted = append(converted, enumValue(priorityValues, v))
		}
	case integerFilterColumns[key]:
		for _, v := range values {
			n, err := strconv.ParseInt(strings.TrimSpace(valueString(v)), 10, 64)
			if err != nil {
				return "", invalidValue(key)
			}
			converted = append(converted, n)
		}
	default:
		converted = values
	}
	return b.compare(cond, converted, "c."+key, "")
}

// enumValue: valor desconhecido vira NULL, como o Conversation.statuses[x] do Rails.
func enumValue(enum map[string]int32, v any) any {
	s, _ := v.(string)
	if n, ok := enum[s]; ok {
		return n
	}
	return nil
}

var priorityValues = map[string]int32{"low": 0, "medium": 1, "high": 2, "urgent": 3}

// compare é o filter_operation para igualdade, ILIKE e presença.
func (b *filterBuilder) compare(cond FilterCondition, values []any, lhs, cast string) (string, error) {
	switch cond.FilterOperator {
	case "equal_to":
		return lhs + " IN (" + b.list(values, cast) + ")", nil
	case "not_equal_to":
		return lhs + " NOT IN (" + b.list(values, cast) + ")", nil
	case "contains", "does_not_contain":
		patterns := make([]any, len(values))
		for i, v := range values {
			patterns[i] = "%" + strings.TrimSpace(valueString(v)) + "%"
		}
		if cond.FilterOperator == "contains" {
			return lhs + " ILIKE ANY (ARRAY[" + b.list(patterns, "") + "])", nil
		}
		return lhs + " NOT ILIKE ALL (ARRAY[" + b.list(patterns, "") + "])", nil
	case "is_present":
		return lhs + " IS NOT NULL", nil
	case "is_not_present":
		return lhs + " IS NULL", nil
	}
	return "", invalidOperator(cond.AttributeKey, nil)
}

// labels é o tag_filter_query (acts_as_taggable_on).
func (b *filterBuilder) labels(cond FilterCondition, values []any) string {
	tagged := "SELECT * FROM taggings WHERE taggings.taggable_id = c.id AND taggings.taggable_type = 'Conversation'"
	switch cond.FilterOperator {
	case "is_present":
		return "EXISTS (" + tagged + ")"
	case "is_not_present":
		return "NOT EXISTS (" + tagged + ")"
	}
	names := make([]any, len(values))
	for i, v := range values {
		names[i] = valueString(v)
	}
	withName := tagged + " AND taggings.tag_id IN (SELECT tags.id FROM tags WHERE tags.name IN (" + b.list(names, "") + "))"
	if cond.FilterOperator == "not_equal_to" {
		return "NOT EXISTS (" + withName + ")"
	}
	return "EXISTS (" + withName + ")"
}

// date cobre is_greater_than/is_less_than/days_before (Filters::DateFilterHelper). Com fuso, um timestamp
// (created_at, last_activity_at) é comparado com a meia-noite local; o resto compara só a data. Em atributo
// personalizado o fuso só decide qual é o "hoje" do days_before.
func (b *filterBuilder) date(cond FilterCondition, values []any, column string, timestamp bool) (string, error) {
	key := cond.AttributeKey
	withTimezone := len(cond.Timezone) > 0
	var loc *time.Location
	if withTimezone {
		var name string
		if err := json.Unmarshal(cond.Timezone, &name); err != nil || name == "" {
			return "", invalidValue("timezone")
		}
		l, err := time.LoadLocation(name)
		if err != nil {
			return "", invalidValue("timezone")
		}
		loc = l
	}

	operator := cond.FilterOperator
	var day time.Time
	if operator == "days_before" {
		days, err := strconv.Atoi(valueString(values[0]))
		if err != nil || days < 1 || days > 998 {
			return "", invalidValue(key)
		}
		today := time.Now().UTC()
		if loc != nil {
			today = time.Now().In(loc)
		}
		day = time.Date(today.Year(), today.Month(), today.Day()-days, 0, 0, 0, 0, time.UTC)
		operator = "is_less_than"
	} else {
		d, ok := parseISODate(valueString(values[0]))
		if !ok {
			return "", invalidValue(key)
		}
		day = d
	}

	if loc != nil && timestamp {
		if operator == "is_greater_than" {
			day = day.AddDate(0, 0, 1)
		}
		boundary := time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, loc).UTC()
		op := ">="
		if operator == "is_less_than" {
			op = "<"
		}
		return fmt.Sprintf("%s %s %s::timestamp", column, op, b.arg(boundary.Format("2006-01-02 15:04:05"))), nil
	}
	op := ">"
	if operator == "is_less_than" {
		op = "<"
	}
	return fmt.Sprintf("(%s)::date %s %s::date", column, op, b.arg(day.Format(time.DateOnly))), nil
}

// parseISODate aceita o que o Date.iso8601 aceita no uso do dashboard: "2024-01-31" ou um timestamp ISO.
func parseISODate(s string) (time.Time, bool) {
	s = strings.TrimSpace(s)
	if d, err := time.Parse(time.DateOnly, s); err == nil {
		return d, true
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC), true
	}
	return time.Time{}, false
}

// customAttribute é o Filters::CustomAttributeFilterHelper: só vale atributo definido na conta.
func (b *filterBuilder) customAttribute(cond FilterCondition, values []any) (string, error) {
	key := cond.AttributeKey
	model, ok := customAttributeModels[cond.CustomAttributeType]
	if !ok {
		return "", invalidAttribute(key)
	}
	var displayType int32
	err := b.db.QueryRow(b.ctx, `SELECT attribute_display_type FROM custom_attribute_definitions
		WHERE account_id = $1 AND attribute_model = $2 AND attribute_key = $3 LIMIT 1`, b.accountID, model, key).Scan(&displayType)
	if err != nil {
		return "", invalidAttribute(key)
	}
	dataType := customAttributeTypes[displayType]

	presence := cond.FilterOperator == "is_present" || cond.FilterOperator == "is_not_present"
	// validate_custom_attribute_values!: data e número precisam ser valores válidos (days_before tem validação própria)
	daysBefore := dataType == "date" && cond.FilterOperator == "days_before"
	if (dataType == "date" || dataType == "numeric") && !presence && !daysBefore {
		for _, v := range values {
			if !validCustomValue(valueString(v), dataType) {
				return "", invalidValue(key)
			}
		}
	}

	// O Chatwoot lê contacts.custom_attributes sem juntar a tabela (erro de SQL); aqui vem por subconsulta.
	source := "c.custom_attributes"
	if model == 1 {
		source = "(SELECT ct.custom_attributes FROM contacts ct WHERE ct.id = c.contact_id)"
	}
	raw := source + " ->> " + b.arg(key)
	lhs := "(" + raw + ")::" + dataType
	if dataType == "text" {
		lhs = "LOWER(" + raw + ")::text"
	}

	switch cond.FilterOperator {
	case "is_greater_than", "is_less_than":
		if dataType != "date" && dataType != "numeric" {
			return "", invalidValue(key)
		}
		op := ">"
		if cond.FilterOperator == "is_less_than" {
			op = "<"
		}
		return fmt.Sprintf("%s %s %s::%s", lhs, op, b.arg(strings.TrimSpace(valueString(values[0]))), dataType), nil
	case "days_before":
		if dataType != "date" {
			return "", invalidValue(key)
		}
		return b.date(cond, values, raw, false)
	case "contains", "does_not_contain":
		if dataType != "text" {
			return "", invalidValue(key)
		}
	}

	// case_insensitive_values: em atributo personalizado, texto compara só o primeiro valor, em minúsculas.
	compared := make([]any, 0, len(values))
	if len(values) > 0 {
		if s, isString := values[0].(string); isString && cond.FilterOperator != "contains" && cond.FilterOperator != "does_not_contain" {
			compared = append(compared, strings.ToLower(s))
		} else {
			for _, v := range values {
				compared = append(compared, valueString(v))
			}
		}
	}
	expr, err := b.compare(cond, compared, lhs, "::"+dataType)
	if err != nil {
		return "", err
	}
	if cond.FilterOperator == "not_equal_to" {
		// not_in_custom_attr_query: quem não tem o atributo também entra. O Chatwoot cola o "OR" depois do
		// operador lógico (SQL inválido se houver outra condição); aqui fica entre parênteses.
		expr = "(" + expr + " OR (" + raw + ")::" + dataType + " IS NULL)"
	}
	return expr, nil
}

func validCustomValue(s, dataType string) bool {
	s = strings.TrimSpace(s)
	if dataType == "date" {
		_, ok := parseISODate(s)
		return ok
	}
	f, ok := new(big.Float).SetString(s)
	return ok && !f.IsInf()
}
