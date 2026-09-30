// Ordenações da lista de contatos (sort_on do ContactsController); '-' na frente é decrescente.
export const CONTACT_SORTS = [
  'name',
  'email',
  'company_name',
  'country',
  'city',
  'last_activity_at',
  'created_at',
] as const
export type ContactSort = (typeof CONTACT_SORTS)[number]
export type ContactOrdering = '' | '-'
