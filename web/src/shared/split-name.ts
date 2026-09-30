// splitName do @chatwoot/utils: a última palavra é o sobrenome, o resto é o nome.
export function splitName(fullName: string): { firstName: string; lastName: string } {
  const parts = fullName.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return { firstName: '', lastName: '' }
  if (parts.length === 1) return { firstName: parts[0]!, lastName: '' }
  return { firstName: parts.slice(0, -1).join(' '), lastName: parts.at(-1)! }
}
