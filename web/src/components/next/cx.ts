type ClassValue = string | false | null | undefined

// Junta classes ignorando os valores vazios, como a lista de classes do HEEx.
export function cx(...values: ClassValue[]): string {
  return values.filter(Boolean).join(' ')
}
