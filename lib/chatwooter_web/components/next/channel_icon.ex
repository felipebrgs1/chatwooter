defmodule ChatwooterWeb.Components.Next.ChannelIcon do
  @moduledoc "Port de `components-next/icon/ChannelIcon.vue` (ícones Phosphor)."
  use ChatwooterWeb, :base_component

  @icons %{telegram: "ph-telegram-logo", whatsapp: "ph-whatsapp-logo"}

  attr :inbox, :map, required: true
  attr :class, :any, default: "size-4"
  attr :rest, :global

  def channel_icon(assigns) do
    assigns = assign(assigns, :icon, Map.get(@icons, assigns.inbox.channel_type, "ph-tray"))

    ~H"""
    <span class={[@icon, @class]} aria-hidden="true" {@rest} />
    """
  end
end
