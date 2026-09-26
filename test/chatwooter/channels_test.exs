defmodule Chatwooter.ChannelsTest do
  @moduledoc "Factory de adapters por canal (Fase 2: Telegram; WhatsApp na Fase 3)."
  use ExUnit.Case, async: true

  alias Chatwooter.Channels
  alias Chatwooter.Channels.Telegram.BotApi

  test "for/1 resolves the telegram adapter" do
    assert {:ok, BotApi} = Channels.for(:telegram)
  end

  test "for/1 returns error for channels without an adapter yet" do
    assert {:error, :not_implemented} = Channels.for(:whatsapp)
    assert {:error, :not_implemented} = Channels.for(:sms)
  end
end
