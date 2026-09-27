defmodule Chatwooter.AccountsUiSettingsTest do
  use Chatwooter.DataCase, async: true

  import Chatwooter.AccountsFixtures

  alias Chatwooter.Accounts

  test "update_ui_settings/2 merges keys into the user's ui settings" do
    user = user_fixture()
    {:ok, user} = Accounts.update_ui_settings(user, %{"conversation_view" => "condensed"})
    {:ok, user} = Accounts.update_ui_settings(user, %{"sidebar_width" => 56})

    assert user.ui_settings == %{"conversation_view" => "condensed", "sidebar_width" => 56}
    assert Accounts.get_user!(user.id).ui_settings["sidebar_width"] == 56
  end

  test "update_ui_settings/2 works when the user has no settings yet" do
    user = user_fixture()
    {:ok, user} = user |> Ecto.Changeset.change(ui_settings: nil) |> Chatwooter.Repo.update()

    assert {:ok, %{ui_settings: %{"sidebar_width" => 240}}} =
             Accounts.update_ui_settings(user, %{"sidebar_width" => 240})
  end
end
