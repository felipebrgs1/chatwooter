package models

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
)

// ContactsPerPage é o RESULTS_PER_PAGE do ContactsController.
const ContactsPerPage = 15

// ContactInbox é o vínculo do contato com uma inbox (_contact_inbox.json.jbuilder).
type ContactInbox struct {
	SourceID string
	Inbox    InboxSlim
}

// InboxSlim é a inbox resumida de _inbox_slim.json.jbuilder.
type InboxSlim struct {
	ID          int32
	ChannelID   int32
	Name        string
	ChannelType string
	Provider    *string
}

// ContactQuery são os parâmetros de listagem: `sort` do Sift (`-` = desc), página (1 em diante),
// `labels[]` (qualquer uma) e se carrega os contact_inboxes (include_contact_inboxes).
type ContactQuery struct {
	Sort        string
	Page        int
	Labels      []string
	WithInboxes bool
}

// ContactPage é uma página de contatos. Count é o total filtrado no index e o tamanho da página na busca;
// HasMore só é calculado na busca (fetch_contacts_with_has_more).
type ContactPage struct {
	Contacts []Contact
	Count    int
	HasMore  bool
}

// Contacts é a parte de leitura do ContactsController (index, search, show).
type Contacts struct {
	db DB
}

func NewContacts(db DB) *Contacts { return &Contacts{db: db} }

const contactColumns = `c.id, c.name, COALESCE(c.email, ''), COALESCE(c.phone_number, ''), COALESCE(c.identifier, ''), c.blocked,
	COALESCE(c.additional_attributes, '{}'), COALESCE(c.custom_attributes, '{}'), c.created_at, c.last_activity_at`

func scanContact(row pgx.Row) (Contact, error) {
	var ct Contact
	var name *string
	err := row.Scan(&ct.ID, &name, &ct.Email, &ct.PhoneNumber, &ct.Identifier, &ct.Blocked,
		&ct.AdditionalAttributes, &ct.CustomAttributes, &ct.CreatedAt, &ct.LastActivityAt)
	if name != nil {
		ct.Name = *name
	}
	return ct, err
}

// Scopes order_on_* do Contact (e o sort_on de tipo string do Sift para email e telefone).
// order_on_name compara com '^+\d*' e '^\b*' dentro de aspas duplas do Ruby: o `\d` vira `d` e o `\b`
// vira backspace (chr(8)); o SQL resultante é reproduzido literalmente.
var contactSorts = map[string]func(dir string) string{
	"name": func(dir string) string {
		return `CASE WHEN c.name ~~* '^+d*' THEN 'z' WHEN c.name ~~* ('^' || chr(8) || '*') THEN 'z' ELSE LOWER(c.name) END ` + dir
	},
	"email":            func(dir string) string { return "c.email " + dir },
	"phone_number":     func(dir string) string { return "c.phone_number " + dir },
	"last_activity_at": func(dir string) string { return "c.last_activity_at " + dir + " NULLS LAST" },
	"created_at":       func(dir string) string { return "c.created_at " + dir + " NULLS LAST" },
	"company_name":     func(dir string) string { return "c.additional_attributes->>'company_name' " + dir + " NULLS LAST" },
	"city":             func(dir string) string { return "c.additional_attributes->>'city' " + dir + " NULLS LAST" },
	"country":          func(dir string) string { return "c.additional_attributes->>'country' " + dir + " NULLS LAST" },
}

// contactOrderBy traduz o `sort` para SQL a partir da lista fechada acima (sort desconhecido é ignorado, como no
// Sift). O id no fim só desempata: sem ele a paginação repetiria ou pularia contatos empatados.
// Sem sort o Chatwoot não ordena; aqui fica a ordem de inserção (id).
func contactOrderBy(sort string) string {
	dir := "ASC"
	if strings.HasPrefix(sort, "-") {
		dir, sort = "DESC", sort[1:]
	}
	if fn, ok := contactSorts[sort]; ok {
		return fn(dir) + ", c.id ASC"
	}
	return "c.id ASC"
}

func offset(page int) int {
	if page < 1 {
		page = 1
	}
	return (page - 1) * ContactsPerPage
}

// List é o index: resolved_contacts (com e-mail, telefone ou identifier) e, se houver, as etiquetas.
func (c *Contacts) List(ctx context.Context, accountID int32, q ContactQuery) (ContactPage, error) {
	where := `c.account_id = $1 AND (c.email <> '' OR c.phone_number <> '' OR c.identifier <> '')`
	args := []any{accountID}
	if len(q.Labels) > 0 {
		// tagged_with(labels, any: true) do acts_as_taggable_on, sem distinguir maiúsculas
		args = append(args, q.Labels)
		where += ` AND EXISTS (SELECT 1 FROM taggings tg JOIN tags t ON t.id = tg.tag_id
			WHERE tg.taggable_type = 'Contact' AND tg.taggable_id = c.id AND tg.context = 'labels'
			AND lower(t.name) = ANY (SELECT lower(l) FROM unnest($2::text[]) l))`
	}
	var page ContactPage
	if err := c.db.QueryRow(ctx, `SELECT count(*) FROM contacts c WHERE `+where, args...).Scan(&page.Count); err != nil {
		return page, err
	}
	contacts, err := c.query(ctx, `SELECT `+contactColumns+` FROM contacts c WHERE `+where+
		` ORDER BY `+contactOrderBy(q.Sort)+` LIMIT `+strconv.Itoa(ContactsPerPage)+` OFFSET `+strconv.Itoa(offset(q.Page)), args...)
	if err != nil {
		return page, err
	}
	page.Contacts = contacts
	return page, c.loadInboxes(ctx, q.WithInboxes, page.Contacts)
}

// Search é o search do controller: qualquer contato da conta (sem o filtro de resolved), ILIKE em nome,
// e-mail e telefone e LIKE (com maiúsculas) no identifier. Busca um a mais para saber se há outra página.
func (c *Contacts) Search(ctx context.Context, accountID int32, term string, q ContactQuery) (ContactPage, error) {
	pattern := "%" + strings.TrimSpace(term) + "%"
	contacts, err := c.query(ctx, `SELECT `+contactColumns+` FROM contacts c WHERE c.account_id = $1
		AND (c.name ILIKE $2 OR c.email ILIKE $2 OR c.phone_number ILIKE $2 OR c.identifier LIKE $2)
		ORDER BY `+contactOrderBy(q.Sort)+` LIMIT `+strconv.Itoa(ContactsPerPage+1)+` OFFSET `+strconv.Itoa(offset(q.Page)), accountID, pattern)
	if err != nil {
		return ContactPage{}, err
	}
	page := ContactPage{Contacts: contacts}
	if len(contacts) > ContactsPerPage {
		page.HasMore, page.Contacts = true, contacts[:ContactsPerPage]
	}
	page.Count = len(page.Contacts)
	return page, c.loadInboxes(ctx, q.WithInboxes, page.Contacts)
}

// Get é o show: o contato da conta, com os contact_inboxes quando pedidos.
func (c *Contacts) Get(ctx context.Context, accountID, id int32, withInboxes bool) (Contact, error) {
	ct, err := scanContact(c.db.QueryRow(ctx, `SELECT `+contactColumns+` FROM contacts c WHERE c.account_id = $1 AND c.id = $2`,
		accountID, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return ct, ErrNotFound
	}
	if err != nil {
		return ct, err
	}
	list := []Contact{ct}
	if err := c.loadInboxes(ctx, withInboxes, list); err != nil {
		return ct, err
	}
	return list[0], nil
}

func (c *Contacts) query(ctx context.Context, sql string, args ...any) ([]Contact, error) {
	rows, err := c.db.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Contact{}
	for rows.Next() {
		ct, err := scanContact(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, ct)
	}
	return out, rows.Err()
}

// loadInboxes preenche ContactInboxes (sempre não nil quando pedido, mesmo sem vínculos).
func (c *Contacts) loadInboxes(ctx context.Context, enabled bool, contacts []Contact) error {
	if !enabled || len(contacts) == 0 {
		return nil
	}
	ids := make([]int32, len(contacts))
	byID := make(map[int32]*[]ContactInbox, len(contacts))
	for i := range contacts {
		ids[i] = contacts[i].ID
		list := []ContactInbox{}
		contacts[i].ContactInboxes = &list
		byID[contacts[i].ID] = &list
	}
	// provider: channel.try(:provider) só existe no WhatsApp; o Telegram não tem a coluna
	rows, err := c.db.Query(ctx, `SELECT ci.contact_id, ci.source_id, i.id, i.channel_id, i.name, COALESCE(i.channel_type, ''), wa.provider
		FROM contact_inboxes ci JOIN inboxes i ON i.id = ci.inbox_id
		LEFT JOIN channel_whatsapp wa ON i.channel_type = 'Channel::Whatsapp' AND wa.id = i.channel_id
		WHERE ci.contact_id = ANY($1) ORDER BY ci.id`, ids)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var contactID int64
		var ci ContactInbox
		if err := rows.Scan(&contactID, &ci.SourceID, &ci.Inbox.ID, &ci.Inbox.ChannelID, &ci.Inbox.Name,
			&ci.Inbox.ChannelType, &ci.Inbox.Provider); err != nil {
			return err
		}
		if list := byID[toInt32(contactID)]; list != nil {
			*list = append(*list, ci)
		}
	}
	return rows.Err()
}
