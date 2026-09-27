defmodule Chatwooter.Inboxes.Inbox do
  @moduledoc "Caixa de entrada de um canal (fase 1: `whatsapp` | `telegram`)."

  use Ecto.Schema
  import Ecto.Changeset

  @channel_types ~w(whatsapp telegram)a

  # Chaves mínimas p/ o adapter funcionar. Inbox sem config é estado
  # válido (cria-se com nome+canal, configura-se depois); config parcial não.
  @required_config %{telegram: ~w(bot_token), whatsapp: ~w(phone_number_id access_token)}

  schema "inboxes" do
    field :name, :string
    field :channel_type, Chatwooter.Types.InboxChannel
    field :channel_id, :integer, default: 0
    field :provider_config, :map, virtual: true, default: %{}, redact: true
    field :greeting_message, :string
    field :allow_messages_after_resolved, :boolean, default: true
    field :auto_assignment_config, :map, default: %{}
    field :business_name, :string
    field :csat_config, :map, default: %{}
    field :csat_survey_enabled, :boolean, default: false
    field :email_address, :string
    field :enable_auto_assignment, :boolean, default: true
    field :enable_email_collect, :boolean, default: true
    field :greeting_enabled, :boolean, default: false
    field :lock_to_single_conversation, :boolean, default: false
    field :out_of_office_message, :string
    field :sender_name_type, :integer, default: 0
    field :timezone, :string, default: "UTC"
    field :working_hours_enabled, :boolean, default: false

    belongs_to :account, Chatwooter.Accounts.Account
    has_many :contact_inboxes, Chatwooter.Contacts.ContactInbox

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(inbox, attrs) do
    inbox
    |> cast(attrs, [:name, :channel_type, :provider_config, :greeting_message])
    |> validate_required([:name, :channel_type])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_length(:greeting_message, max: 1000)
    |> validate_inclusion(:channel_type, @channel_types)
    |> validate_provider_config()
  end

  @doc """
  Changeset de atualização: `channel_type` é imutável após a criação
  (como no Chatwoot original) e por isso fica fora do cast.
  """
  def update_changeset(inbox, attrs) do
    inbox
    |> cast(attrs, [:name, :provider_config, :greeting_message])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_length(:greeting_message, max: 1000)
    |> validate_provider_config()
  end

  defp validate_provider_config(changeset) do
    changeset = normalize_provider_config(changeset)

    validate_change(changeset, :provider_config, fn :provider_config, config ->
      config_errors(get_field(changeset, :channel_type), config)
    end)
  end

  defp config_errors(_channel, nil), do: []
  defp config_errors(_channel, config) when config == %{}, do: []

  defp config_errors(channel, config) do
    required = Map.get(@required_config, channel, [])

    case required -- present_keys(config, required) do
      [] -> []
      missing -> [provider_config: "missing required keys: #{Enum.join(missing, ", ")}"]
    end
  end

  # Zera configs "vazias" (ex. token em branco): viram inbox não-configurado,
  # que é estado válido — configura-se depois.
  defp normalize_provider_config(changeset) do
    case get_change(changeset, :provider_config) do
      config when is_map(config) -> maybe_clear_provider_config(changeset, config)
      _ -> changeset
    end
  end

  defp maybe_clear_provider_config(changeset, config) do
    if blank_config?(config),
      do: put_change(changeset, :provider_config, %{}),
      else: changeset
  end

  defp blank_config?(config) do
    Enum.all?(config, fn {_key, value} -> blank_value?(value) end)
  end

  defp blank_value?(nil), do: true
  defp blank_value?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank_value?(_value), do: false

  defp present_keys(config, required) do
    Enum.filter(required, fn key ->
      value = Map.get(config, key) || Map.get(config, String.to_atom(key))
      is_binary(value) and String.trim(value) != ""
    end)
  end
end
