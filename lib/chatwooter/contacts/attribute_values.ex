defmodule Chatwooter.Contacts.AttributeValues do
  @moduledoc "Preserves JSONB values, including the upstream array default, without coercion."
  use Ecto.Type

  def type, do: :map

  def cast(value) do
    case Jason.encode(value) do
      {:ok, _json} -> {:ok, value}
      {:error, _reason} -> :error
    end
  end

  def load(value), do: {:ok, value}
  def dump(value), do: cast(value)
end
