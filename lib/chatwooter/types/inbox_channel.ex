defmodule Chatwooter.Types.InboxChannel do
  @moduledoc "Preserves Rails polymorphic channel names and exposes the supported adapters as atoms."
  use Ecto.Type

  def type, do: :string
  def cast(value) when value in [:telegram, :whatsapp], do: {:ok, value}
  def cast("telegram"), do: {:ok, :telegram}
  def cast("whatsapp"), do: {:ok, :whatsapp}
  def cast(value) when is_binary(value), do: load(value)
  def cast(_value), do: :error
  def load("Channel::Telegram"), do: {:ok, :telegram}
  def load("Channel::Whatsapp"), do: {:ok, :whatsapp}
  def load(value) when is_binary(value), do: {:ok, value}
  def load(_value), do: :error
  def dump(:telegram), do: {:ok, "Channel::Telegram"}
  def dump(:whatsapp), do: {:ok, "Channel::Whatsapp"}
  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(_value), do: :error
end
