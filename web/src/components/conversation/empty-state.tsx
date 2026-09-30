// Porta de components/widgets/conversation/EmptyState/EmptyState.vue + EmptyStateMessage.vue
// (só o caso "há conversas, nenhuma selecionada"; o onboarding sem inbox vem com as settings).
import { useTranslation } from 'react-i18next'

export function EmptyState() {
  const { t } = useTranslation()
  return (
    <div className="flex h-full min-w-0 flex-1 flex-col items-center justify-center bg-n-surface-1 px-0">
      <div className="flex h-full flex-col items-center justify-center">
        <img className="m-4 hidden w-32 dark:block" src="/images/no-chat-dark.svg" alt="" />
        <img className="m-4 block w-32 dark:hidden" src="/images/no-chat.svg" alt="" />
        <span className="text-center text-sm font-medium text-n-slate-12">
          {t('CONVERSATION.SELECT_A_CONVERSATION')}
        </span>
      </div>
    </div>
  )
}
