import i18next, { type i18n, type PostProcessorModule } from 'i18next'
import resourcesToBackend from 'i18next-resources-to-backend'
import { initReactI18next } from 'react-i18next'

export const locales = ['en', 'pt_BR'] as const
export type Locale = (typeof locales)[number]

// Um arquivo por namespace do Chatwoot (login.json, conversation.json...); carregados sob demanda.
const files = import.meta.glob<Record<string, unknown>>('./locales/*/*.json', { import: 'default' })

// Mesma regra do locale/<lang>/index.js do Chatwoot: todos os arquivos fundidos num objeto só.
async function loadLocale(locale: string) {
  const prefix = `./locales/${locale}/`
  const paths = Object.keys(files)
    .filter((p) => p.startsWith(prefix))
    .sort()
  const modules = await Promise.all(paths.map((p) => files[p]()))
  return Object.assign({}, ...modules) as Record<string, unknown>
}

export function resolveLocale(input: string): Locale {
  const normalized = input.replace('-', '_').toLowerCase()
  if (normalized === 'pt' || normalized === 'pt_br') return 'pt_BR'
  return 'en'
}

// Os textos usam a sintaxe do vue-i18n: {nome}, {'literal'} e "singular | plural".
// O i18next não sabe isso, então a interpolação própria dele fica desligada e tratamos aqui.
const vueI18n: PostProcessorModule = {
  type: 'postProcessor',
  name: 'vueI18n',
  process(value: string, _key: string | string[], options: Record<string, unknown>) {
    let text = value
    const count = options.count
    if (typeof count === 'number' && text.includes(' | ')) {
      text = text.split(' | ')[pluralIndex(count, text.split(' | ').length)]
    }
    return text.replace(/\{'([^']*)'\}|\{\s*([\w.]+)\s*\}/g, (whole, literal, name) => {
      if (literal !== undefined) return literal as string
      const replacement = options[name as string]
      return replacement === undefined ? whole : String(replacement)
    })
  },
}

// Regra do vue-i18n: com 2 formas, 1 é singular; com 3, as formas são 0, 1 e n.
function pluralIndex(count: number, choices: number) {
  if (choices === 2) return count === 1 ? 0 : 1
  return count === 0 ? 0 : count === 1 ? 1 : Math.min(2, choices - 1)
}

export async function createI18n(locale: string): Promise<i18n> {
  const instance = i18next.createInstance()
  await instance
    .use(vueI18n)
    .use(initReactI18next)
    .use(resourcesToBackend((language: string) => loadLocale(language)))
    .init({
      lng: resolveLocale(locale),
      fallbackLng: 'en',
      supportedLngs: [...locales],
      ns: ['translation'],
      defaultNS: 'translation',
      postProcess: ['vueI18n'],
      // prefixo/sufixo que nunca aparecem nos textos: desliga o {{ }} do i18next
      interpolation: { prefix: '\u0001', suffix: '\u0002', escapeValue: false },
    })
  return instance
}
