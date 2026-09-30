package views

import "github.com/felipeborgaco/chatwooter/server/internal/models"

// ContactsMetaJSON é o meta de contacts/index.json.jbuilder; HasMore só existe no search.json.jbuilder.
// CurrentPage ecoa `params[:page] || 1`: o texto do parâmetro quando veio, o número 1 quando não.
type ContactsMetaJSON struct {
	Count       int   `json:"count"`
	CurrentPage any   `json:"current_page"`
	HasMore     *bool `json:"has_more,omitempty"`
}

type ContactsJSON struct {
	Meta    ContactsMetaJSON `json:"meta"`
	Payload []ContactJSON    `json:"payload"`
}

// ContactsPage monta index e search: withHasMore liga o `has_more` da busca.
func ContactsPage(p models.ContactPage, currentPage any, withHasMore bool) ContactsJSON {
	out := ContactsJSON{
		Meta:    ContactsMetaJSON{Count: p.Count, CurrentPage: currentPage},
		Payload: make([]ContactJSON, 0, len(p.Contacts)),
	}
	if withHasMore {
		hasMore := p.HasMore
		out.Meta.HasMore = &hasMore
	}
	for _, c := range p.Contacts {
		out.Payload = append(out.Payload, Contact(c))
	}
	return out
}

// ContactShow é o contacts/show.json.jbuilder: {payload: contato}.
func ContactShow(c models.Contact) map[string]ContactJSON {
	return map[string]ContactJSON{"payload": Contact(c)}
}
