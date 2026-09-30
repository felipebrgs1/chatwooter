// Porta do formulário de v3/views/login/Index.vue (sem Google OAuth, SAML, MFA nem limite de sessões: fora do v1).
import { useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '../next'
import { showAlert } from '../toast/alert'
import { FormInput } from './form-input'

interface Props {
  onSubmit: (email: string, password: string) => Promise<void>
}

const EMAIL_FORMAT = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export function LoginForm({ onSubmit }: Props) {
  const { t } = useTranslation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [errored, setErrored] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!EMAIL_FORMAT.test(email)) {
      showAlert(t('LOGIN.EMAIL.ERROR'))
      return
    }
    setErrored(false)
    setLoading(true)
    try {
      await onSubmit(email, password)
      showAlert(t('LOGIN.API.SUCCESS_MESSAGE'))
    } catch {
      setErrored(true)
      setLoading(false)
      // O Chatwoot mostra sempre a mensagem traduzida, não a que o servidor devolve.
      showAlert(t('LOGIN.API.UNAUTH'))
    }
  }

  return (
    <form className="space-y-5" onSubmit={submit} noValidate>
      <FormInput
        label={t('LOGIN.EMAIL.LABEL')}
        name="email_address"
        type="text"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder={t('LOGIN.EMAIL.PLACEHOLDER')}
        required
        tabIndex={1}
      />
      <FormInput
        label={t('LOGIN.PASSWORD.LABEL')}
        name="password"
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder={t('LOGIN.PASSWORD.PLACEHOLDER')}
        required
        tabIndex={2}
        rightOfLabel={
          // sem rota ainda (reset de senha): aparece só visual, sem link quebrado
          <span className="text-sm text-n-brand" aria-disabled="true">
            {t('LOGIN.FORGOT_PASSWORD')}
          </span>
        }
      />
      <Button
        type="submit"
        size="lg"
        className={errored ? 'w-full animate-wiggle' : 'w-full'}
        tabIndex={3}
        label={t('LOGIN.SUBMIT')}
        disabled={loading}
      />
    </form>
  )
}
