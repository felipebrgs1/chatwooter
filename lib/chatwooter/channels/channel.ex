defmodule Chatwooter.Channels.Channel do
  @moduledoc """
  Port de canais (WhatsApp Cloud API, Telegram Bot API).

  Todo HTTP externo com Meta/Telegram passa por aqui. `Conversations`,
  workers e a Web falam com canais só via este Behaviour, resolvendo o
  adapter com `Chatwooter.Channels.for/1`.
  """

  @type inbox :: map()

  @type outgoing :: %{
          required(:to) => String.t(),
          required(:content) => String.t(),
          optional(:reply_to_external_id) => String.t()
        }

  @type incoming :: %{
          required(:channel) => atom(),
          required(:source_id) => String.t(),
          required(:type) => :text | :image,
          required(:external_id) => String.t(),
          optional(:sender_name) => String.t() | nil,
          optional(:content) => String.t() | nil,
          optional(:file_id) => String.t() | nil,
          optional(:timestamp) => integer() | nil
        }

  @doc """
  Envia uma mensagem de texto pelo canal.

  `message.to` é o destinatário no vocabulário do canal (chat_id no
  Telegram, telefone wa_id no WhatsApp) e `message.content` o texto.
  """
  @callback send_message(inbox(), outgoing()) ::
              {:ok, %{external_id: String.t()}} | {:error, term()}

  @doc """
  Normaliza o payload bruto do webhook em mensagens de entrada.

  Retorna `{:ok, []}` para updates sem mensagem processável
  (polls, reactions, edições) — o chamador só ignora.
  """
  @callback parse_webhook(params :: map()) :: {:ok, [incoming()]} | {:error, term()}

  @doc """
  Valida que o webhook veio do provider (secret do Telegram,
  assinatura HMAC da Meta). Inbox sem segredo configurado aceita
  (canal ainda não configurado).
  """
  @callback validate_webhook(conn :: Plug.Conn.t(), inbox()) :: :ok | {:error, term()}
end
