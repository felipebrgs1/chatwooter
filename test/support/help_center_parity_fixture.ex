defmodule Chatwooter.HelpCenterParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    [
      {Chatwooter.Platform.Portal,
       %{
         id: 93_001,
         account_id: 7001,
         name: "Help",
         slug: "help-fixture",
         custom_domain: "help.example.test",
         color: "blue",
         homepage_link: "https://example.test",
         page_title: "Help center",
         header_text: "Welcome",
         channel_web_widget_id: 5_000_000_001,
         created_at: @created,
         updated_at: @created
       }, %{config: %{"allowed_locales" => ["en"]}, archived: false, ssl_settings: %{}}},
      {Chatwooter.Platform.PortalMember, %{portal_id: 93_001, user_id: 5_000_000_002}, %{}},
      {Chatwooter.Platform.Category,
       %{
         id: 93_002,
         account_id: 7001,
         portal_id: 93_001,
         name: "Getting started",
         description: "Category text",
         position: 3,
         slug: "getting-started",
         parent_category_id: 5_000_000_003,
         associated_category_id: 5_000_000_004,
         created_at: @created,
         updated_at: @created
       }, %{locale: "en", icon: "", icon_color: ""}},
      {Chatwooter.Platform.Article,
       %{
         id: 93_003,
         account_id: 7001,
         portal_id: 93_001,
         category_id: 93_002,
         folder_id: 7,
         title: "Welcome",
         description: "Article description",
         content: "Article content",
         status: 1,
         views: 23,
         author_id: 5_000_000_005,
         associated_article_id: 5_000_000_006,
         slug: "welcome-fixture",
         position: 2,
         draft_title: "Draft welcome",
         draft_content: "Draft content",
         created_at: @created,
         updated_at: @created
       }, %{meta: %{}, locale: "en"}},
      {Chatwooter.Platform.RelatedCategory,
       %{
         id: 93_004,
         category_id: 93_002,
         related_category_id: 5_000_000_007,
         created_at: @created,
         updated_at: @created
       }, %{}}
    ]
  end

  def insert!(repo) do
    for {schema, attrs, _defaults} <- rows() do
      columns = Map.keys(attrs) |> Enum.sort()
      keys = Enum.map_join(columns, ", ", &Atom.to_string/1)
      placeholders = 1..length(columns) |> Enum.map_join(", ", &"$#{&1}")
      values = Enum.map(columns, &Map.fetch!(attrs, &1))
      table = schema.__schema__(:source)
      repo.query!("INSERT INTO #{table} (#{keys}) VALUES (#{placeholders})", values)
    end

    :ok
  end
end
