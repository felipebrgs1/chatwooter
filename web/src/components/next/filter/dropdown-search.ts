// helper/filterHelper.js → DROPDOWN_SEARCH_THRESHOLD: acima disso o dropdown ganha busca. Atributo e valor
// usam o mesmo limite para nunca discordarem.
export const DROPDOWN_SEARCH_THRESHOLD = 8

/** Busca simples por trecho, sem diferenciar maiúsculas (o picoSearch do Chatwoot). */
export function matches(text: string, query: string) {
  return text.toLowerCase().includes(query.trim().toLowerCase())
}
