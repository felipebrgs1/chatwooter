import { beforeEach, describe, expect, test } from 'vitest'

import { createI18n } from './index'

describe('i18n', () => {
  let i18n: Awaited<ReturnType<typeof createI18n>>

  beforeEach(async () => {
    i18n = await createI18n('en')
  })

  test('lê as chaves do Chatwoot em inglês', () => {
    expect(i18n.t('LOGIN.TITLE')).toBe('Login to Chatwoot')
  })

  test('troca para pt_BR carregando o idioma sob demanda', async () => {
    await i18n.changeLanguage('pt_BR')
    expect(i18n.t('LOGIN.TITLE')).not.toBe('Login to Chatwoot')
    expect(i18n.t('LOGIN.TITLE')).toMatch(/Chatwoot/)
  })

  test('aceita "pt" como apelido de pt_BR', async () => {
    const pt = await createI18n('pt')
    expect(pt.language).toBe('pt_BR')
  })

  test('interpola {variavel} como o vue-i18n', () => {
    expect(i18n.t('CONVERSATION.CAPTAIN_GENERATION.SOURCES_SUMMARY', { count: 3 })).toBe(
      '3 results',
    )
  })

  test('plural de duas formas: singular e plural', () => {
    expect(i18n.t('CONVERSATION.CAPTAIN_GENERATION.SOURCES_SUMMARY', { count: 1 })).toBe('1 result')
  })

  test("literais {'x'} viram o próprio texto", () => {
    expect(i18n.t('LOGIN.EMAIL.PLACEHOLDER')).toBe('example@companyname.com')
  })

  test('idioma não suportado cai para inglês', async () => {
    const fr = await createI18n('fr')
    expect(fr.language).toBe('en')
  })
})
