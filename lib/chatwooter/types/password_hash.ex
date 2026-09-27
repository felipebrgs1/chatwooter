defmodule Chatwooter.Types.PasswordHash do
  @moduledoc "Keeps the local nil-password API for Devise's empty encrypted_password representation."
  use Ecto.Type

  def type, do: :string
  def cast(value) when is_binary(value) or is_nil(value), do: {:ok, value}
  def cast(_value), do: :error
  def load(""), do: {:ok, nil}
  def load(value), do: {:ok, value}
  def dump(nil), do: {:ok, ""}
  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(_value), do: :error
end
