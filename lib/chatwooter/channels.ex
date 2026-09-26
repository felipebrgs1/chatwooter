defmodule Chatwooter.Channels do
  @moduledoc "Factory de adapters de canal (`Chatwooter.Channels.Channel`)."

  alias Chatwooter.Channels.Telegram.BotApi

  @doc "Resolve o adapter do canal. Canais sem adapter retornam erro explícito."
  def for(:telegram), do: {:ok, BotApi}
  def for(_channel), do: {:error, :not_implemented}
end
