// Nome do arquivo a partir da URL do anexo (como File.vue).
export function fileNameOf(url: string, unknown: string) {
  const name = url.substring(url.lastIndexOf('/') + 1).split('?')[0]
  if (!name) return unknown
  try {
    return decodeURIComponent(name)
  } catch {
    return name
  }
}
