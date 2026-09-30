// Copia os textos do Chatwoot (só en e pt_BR) para src/i18n/locales. O clone em chatwoot/ não é versionado,
// então os JSON copiados ficam no repositório; rode de novo ao atualizar a referência.
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const source = join(here, '../../chatwoot/app/javascript/dashboard/i18n/locale')
const target = join(here, '../src/i18n/locales')
const locales = ['en', 'pt_BR']

for (const locale of locales) {
  const from = join(source, locale)
  if (!existsSync(from)) throw new Error(`locale não encontrado: ${from}`)
  const to = join(target, locale)
  rmSync(to, { recursive: true, force: true })
  mkdirSync(to, { recursive: true })
  for (const file of readdirSync(from).filter((f) => f.endsWith('.json'))) {
    cpSync(join(from, file), join(to, file))
  }
}
console.log(`i18n sincronizado: ${locales.join(', ')}`)
