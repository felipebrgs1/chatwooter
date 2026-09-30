package views

import "github.com/felipeborgaco/chatwooter/server/internal/models"

// CompanyContactJSON mirrors companies/contacts/_contact.json.jbuilder.
type CompanyContactJSON struct {
	ContactJSON
	Company *CompanyResponse `json:"company"`
	Linked  bool             `json:"linked_to_current_company"`
}

func CompanyContact(c models.CompanyContact) CompanyContactJSON {
	out := CompanyContactJSON{ContactJSON: Contact(c.Contact), Linked: c.Linked}
	if c.Company != nil {
		company := Company(*c.Company)
		out.Company = &company
	}
	return out
}

func CompanyContacts(p models.CompanyContactsPage, page any) any {
	payload := []CompanyContactJSON{}
	for _, c := range p.Contacts {
		payload = append(payload, CompanyContact(c))
	}
	return struct {
		Meta    any                  `json:"meta"`
		Payload []CompanyContactJSON `json:"payload"`
	}{struct {
		Total int64 `json:"total_count"`
		Page  any   `json:"page"`
	}{p.Total, page}, payload}
}

// CompanyNotes mirrors companies/notes/index.json.jbuilder.
func CompanyNotes(notes []models.CompanyNote) any {
	type item struct {
		NoteJSON
		Contact ContactJSON `json:"contact"`
	}
	payload := []item{}
	for _, n := range notes {
		payload = append(payload, item{Note(n.Note), Contact(n.Contact)})
	}
	return struct {
		Payload []item `json:"payload"`
	}{payload}
}
