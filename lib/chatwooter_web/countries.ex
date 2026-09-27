defmodule ChatwooterWeb.Countries do
  @moduledoc """
  Lista de países (nome, DDI, bandeira) de `chatwoot/app/javascript/shared/constants/countries.js`,
  exportada para `priv/countries.json`. Usada no campo de país e no DDI do telefone.
  """

  @path Path.expand("../../priv/countries.json", __DIR__)
  @external_resource @path
  @countries @path |> File.read!() |> Jason.decode!(keys: :atoms)
  @by_id Map.new(@countries, &{&1.id, &1})

  # DDIs compartilhados (+1, +7, +44...): o Chatwoot resolve com libphonenumber;
  # aqui usamos o país "dono" do código quando o número não diz mais nada.
  @preferred %{"+1" => "US", "+7" => "RU", "+44" => "GB", "+47" => "NO", "+61" => "AU"}

  # mais longo primeiro, para "+1684" (Samoa) vencer "+1"
  @by_dial_code @countries
                |> Enum.group_by(& &1.dial_code)
                |> Enum.map(fn {dial, [first | _] = list} ->
                  {dial, Enum.find(list, first, &(&1.id == @preferred[dial]))}
                end)
                |> Enum.sort_by(fn {dial, _country} -> -byte_size(dial) end)

  def all, do: @countries
  def get(id), do: Map.get(@by_id, id)

  @doc "Separa um número E.164 em `{país, número local}`; `{nil, número}` se não reconhecer o DDI."
  def split_phone(phone) when phone in [nil, ""], do: {nil, ""}

  def split_phone("+" <> _ = phone) do
    case Enum.find(@by_dial_code, fn {dial, _country} -> String.starts_with?(phone, dial) end) do
      {dial, country} -> {country, String.replace_prefix(phone, dial, "")}
      nil -> {nil, phone}
    end
  end

  def split_phone(phone), do: {nil, phone}
end
