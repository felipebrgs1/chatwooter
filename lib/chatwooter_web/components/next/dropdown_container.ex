defmodule ChatwooterWeb.Components.Next.DropdownContainer do
  @moduledoc "Abrir/fechar menus (`dropdown-menu/base/DropdownContainer.vue`) com JS commands."
  use ChatwooterWeb, :base_component

  @doc """
  Alterna o corpo `#<id>-body` do menu e o realce do gatilho `#<id>-trigger`.
  Use com `phx-click-away={close_dropdown(id)}` no contêiner.
  """
  def toggle_dropdown(js \\ %JS{}, id) do
    js
    |> JS.toggle_attribute({"hidden", "hidden"}, to: "##{id}-body")
    |> JS.toggle_class("bg-n-alpha-1", to: "##{id}-trigger")
  end

  def close_dropdown(js \\ %JS{}, id) do
    js
    |> JS.set_attribute({"hidden", "hidden"}, to: "##{id}-body")
    |> JS.remove_class("bg-n-alpha-1", to: "##{id}-trigger")
  end
end
