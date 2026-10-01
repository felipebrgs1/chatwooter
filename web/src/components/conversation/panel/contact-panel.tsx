// Port de routes/dashboard/conversation/ContactPanel.vue + components/widgets/conversation/ConversationSidebar.vue:
// o painel à direita da conversa. Por ora só o acordeão "Conversation Actions"; os demais (info da conversa,
// atributos, notas, arquivos, conversas anteriores, participantes, macros) e a reordenação por arrasto
// (conversation_sidebar_items_order) entram nas próximas fatias.
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { contactQuery } from '../../../api/contacts'
import type { Conversation } from '../../../api/types'
import { useAccountId } from '../../../api/use-account-id'
import { useUiSettings } from '../../../api/use-ui-settings'
import { SidebarActionsHeader } from '../../next/sidebar-actions-header'
import { AccordionItem } from './accordion-item'
import { ContactInfo } from './contact-info'
import { ConversationAction } from './conversation-action'

type Props = { conversation: Conversation }

export function ContactPanel({ conversation }: Props) {
  const { t } = useTranslation()
  const accountId = useAccountId()
  const { uiSettings, update } = useUiSettings()
  const sender = conversation.meta.sender
  const { data: contact = sender } = useQuery(contactQuery(accountId, sender.id))
  const title = t('CONVERSATION.SIDEBAR.CONTACT')
  // isContactSidebarItemOpen / toggleSidebarUIState
  const isOpen = (key: string) => !!uiSettings[key]
  const toggle = (key: string) => void update({ [key]: !uiSettings[key] })

  return (
    <aside
      aria-label={title}
      className="bg-n-surface-2 h-full overflow-hidden flex flex-col fixed top-0 z-40 w-full max-w-sm transition-transform duration-300 ease-in-out ltr:right-0 rtl:left-0 md:static md:w-[320px] md:min-w-[320px] ltr:border-l rtl:border-r border-n-weak 2xl:min-w-[360px] 2xl:w-[360px] shadow-lg md:shadow-none md:flex"
    >
      <div className="flex flex-1 overflow-auto">
        <div className="w-full">
          <SidebarActionsHeader
            title={title}
            onClose={() =>
              void update({ is_contact_sidebar_open: false, is_copilot_panel_open: false })
            }
          />
          <ContactInfo contact={contact} />
          <div className="px-2 pb-8 list-group">
            <div className="flex flex-col gap-3">
              <AccordionItem
                title={t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_ACTIONS')}
                isOpen={isOpen('is_conv_actions_open')}
                onToggle={() => toggle('is_conv_actions_open')}
              >
                <ConversationAction conversation={conversation} />
              </AccordionItem>
            </div>
          </div>
        </div>
      </div>
    </aside>
  )
}
