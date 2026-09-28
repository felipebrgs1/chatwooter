defmodule ChatwooterWeb.Components do
  @moduledoc """
  Registro dos componentes do app. Cada componente vive em
  `lib/chatwooter_web/components/<área>/<nome>.ex` como
  `ChatwooterWeb.Components.<Área>.<Nome>` e expõe funções com nome único.

    * `use ChatwooterWeb.Components` — importa todos (feito por `:html`/`:live_view`)
    * `use ChatwooterWeb.Components, :next` — só os componentes base (feito por `:component`)

  Componente novo? Crie o arquivo e registre o módulo numa das listas abaixo.
  """

  # components-next genéricos do Chatwoot (sem regra de negócio)
  @next [
    Next.Avatar,
    Next.Breadcrumb,
    Next.Button,
    Next.ChannelIcon,
    Next.Checkbox,
    Next.Combobox,
    Next.Dialog,
    Next.DropdownContainer,
    Next.DropdownMenu,
    Next.Input,
    Next.SearchableList,
    Next.Switch,
    Next.TabBar
  ]

  # componentes de tela, agrupados pela área do Chatwoot
  @screens [
    Sidebar.Sidebar,
    Companies.CompanyFormModal,
    Settings.SettingsLayout,
    Conversation.ChatListHeader,
    Conversation.ChatTypeTabs,
    Conversation.ConversationCard,
    Conversation.ConversationCardExpanded,
    Conversation.CardLabels,
    Conversation.CardLink,
    Conversation.CardSelect,
    Conversation.ContextMenu,
    Conversation.DeleteConversationDialog,
    Conversation.BulkActions,
    Conversation.BulkActionMenu,
    Conversation.FilterEditor,
    Conversation.SaveCustomView,
    Conversation.DeleteCustomView,
    Conversation.FilterCondition,
    Conversation.FilterSelect,
    Conversation.FilterMultiSelect,
    Contacts.ContactProfile,
    Contacts.ContactForm,
    Contacts.ContactAttributes,
    Contacts.ContactHistory,
    Contacts.ContactNotes,
    Contacts.ContactMedia,
    Contacts.ContactMerge,
    NewConversation.ComposeConversation,
    Search.SearchInput,
    Search.RecentSearches,
    Search.SearchResultSection,
    Search.SearchResultContactItem,
    Search.SearchResultConversationItem,
    Search.SearchResultMessageItem
  ]

  defmacro __using__(scope) do
    modules = if scope == :next, do: @next, else: @next ++ @screens

    for module <- modules do
      quote do: import(unquote(Module.concat(__MODULE__, module)))
    end
  end
end
