defmodule ChatwooterWeb.ConversationsLive.FilterEditor do
  @moduledoc "State for ConversationFilter.vue, SaveCustomView.vue and DeleteCustomViews.vue."
  use ChatwooterWeb, :verified_routes
  import Phoenix.Component
  import Phoenix.LiveView
  alias Chatwooter.{Accounts, Automations, Contacts, Inboxes}
  alias Chatwooter.Conversations.FilterQuery

  @languages_path Path.expand("../../../../priv/filter_languages.json", __DIR__)
  @external_resource @languages_path
  @languages @languages_path
             |> File.read!()
             |> Jason.decode!()
             |> Enum.map(&{&1["id"], &1["name"]})

  def mount(socket) do
    definitions =
      if socket.assigns.account,
        do:
          Contacts.list_custom_attribute_definitions(socket.assigns.account)
          |> Enum.filter(
            &(&1.attribute_model == :conversation_attribute &&
                &1.attribute_display_type in [:text, :number, :link, :date, :list, :checkbox])
          )
          |> Enum.reject(&FilterQuery.standard_attribute?(&1.attribute_key)),
        else: []

    socket
    |> assign(:custom_filter_definitions, definitions)
    |> assign(
      :filter_labels,
      if(socket.assigns.account, do: Contacts.list_labels(socket.assigns.account), else: [])
    )
    |> assign(:filter_value_options, value_options(socket.assigns.account))
    |> assign(:filter_contact_options, %{})
    |> assign(:advanced_query, nil)
    |> assign(:filter_editor, nil)
    |> assign(:filter_error, nil)
    |> assign(:filter_rows, [])
    |> assign(:filter_form, to_form(%{}, as: "filters"))
    |> assign(:folder_form, to_form(%{"name" => ""}, as: "folder"))
    |> attach_hook(:filter_editor, :handle_event, &event/3)
  end

  def from_params(socket, params) do
    query =
      with text when is_binary(text) <- params["filters"],
           {:ok, query} <- Jason.decode(text),
           {:ok, _} <- FilterQuery.compile(query, socket.assigns.account) do
        query
      else
        _ -> nil
      end

    assign(socket, :advanced_query, query)
  end

  defp event("filter:open", _, socket) do
    query =
      (socket.assigns.folder && socket.assigns.folder.query) || socket.assigns.advanced_query

    conditions = query && query["payload"]

    rows =
      if is_list(conditions) && conditions != [] && Enum.all?(conditions, &is_map/1),
        do: Enum.map(conditions, &editable_row/1),
        else: [default_row()]

    name = if socket.assigns.folder, do: socket.assigns.folder.name, else: ""

    {:halt,
     socket
     |> assign(:filter_editor, :edit)
     |> assign(:filter_error, nil)
     |> assign(:filter_contact_options, selected_contacts(socket.assigns.account, rows))
     |> set_form(rows, name)}
  end

  defp event("filter:close", _, socket), do: {:halt, assign(socket, :filter_editor, nil)}

  defp event("filter:pick", %{"index" => index, "field" => field, "value" => value}, socket)
       when is_integer(index) and field in ~w(attribute_key filter_operator) and is_binary(value) do
    params = socket.assigns.filter_form.params
    rows = rows(params)

    updated =
      if index >= 0 && index < length(rows) do
        List.update_at(rows, index, fn row -> normalize_row(Map.put(row, field, value), row) end)
      else
        rows
      end

    socket =
      if field == "attribute_key",
        do: update(socket, :filter_contact_options, &Map.delete(&1, index)),
        else: socket

    {:halt, set_form(socket, updated, params["name"] || "")}
  end

  defp event("filter:pick", _, socket), do: {:halt, socket}

  defp event("filter:pick_join", %{"index" => index, "value" => value}, socket)
       when is_integer(index) and index >= 0 and value in ~w(and or) do
    params = socket.assigns.filter_form.params
    current = rows(params)

    if index < length(current) - 1 do
      next = List.update_at(current, index, &Map.put(&1, "query_operator", value))
      {:halt, set_form(socket, next, params["name"] || "")}
    else
      {:halt, socket}
    end
  end

  defp event("filter:pick_join", _, socket), do: {:halt, socket}

  defp event("filter:toggle_value", %{"index" => index, "value" => value}, socket)
       when is_integer(index) and index >= 0 and is_binary(value) do
    params = socket.assigns.filter_form.params
    current = rows(params)
    row = Enum.at(current, index)

    if row && value in allowed_values(row["attribute_key"], socket.assigns.filter_labels) do
      selected = decode_multi(row["values"])
      selected = if value in selected, do: List.delete(selected, value), else: selected ++ [value]
      next = List.update_at(current, index, &Map.put(&1, "values", Jason.encode!(selected)))
      {:halt, set_form(socket, next, params["name"] || "")}
    else
      {:halt, socket}
    end
  end

  defp event("filter:toggle_value", _, socket), do: {:halt, socket}

  defp event("filter:pick_value", %{"index" => index, "value" => value}, socket)
       when is_integer(index) and index >= 0 and is_binary(value) do
    params = socket.assigns.filter_form.params
    current = rows(params)
    row = Enum.at(current, index)

    allowed =
      if row, do: Map.get(socket.assigns.filter_value_options, row["attribute_key"], []), else: []

    allowed =
      if row && row["attribute_key"] == "contact_id",
        do: Map.get(socket.assigns.filter_contact_options, index, []),
        else: allowed

    if Enum.any?(allowed, fn {id, _label} -> id == value end) do
      next = List.update_at(current, index, &Map.put(&1, "values", value))
      {:halt, set_form(socket, next, params["name"] || "")}
    else
      {:halt, socket}
    end
  end

  defp event("filter:pick_value", _, socket), do: {:halt, socket}

  defp event("filter:pick_custom_value", %{"index" => index, "value" => value}, socket)
       when is_integer(index) and index >= 0 and is_binary(value) do
    params = socket.assigns.filter_form.params
    current = rows(params)
    row = Enum.at(current, index)

    definition =
      row &&
        Enum.find(
          socket.assigns.custom_filter_definitions,
          &(&1.attribute_key == row["attribute_key"])
        )

    if value in custom_value_options(definition) do
      next = List.update_at(current, index, &Map.put(&1, "values", value))
      {:halt, set_form(socket, next, params["name"] || "")}
    else
      {:halt, socket}
    end
  end

  defp event("filter:pick_custom_value", _, socket), do: {:halt, socket}

  defp event("filter:search_contact", %{"index" => index} = params, socket) do
    query = params["query"] || params["value"]
    index = if is_integer(index), do: index, else: parse_index(index)

    row =
      if is_integer(index) && index >= 0,
        do: Enum.at(rows(socket.assigns.filter_form.params), index),
        else: nil

    if row && row["attribute_key"] == "contact_id" && is_binary(query) && socket.assigns.account do
      options =
        Contacts.search_filter_contacts(socket.assigns.account, query)
        |> Enum.map(&contact_option/1)

      {:halt, update(socket, :filter_contact_options, &Map.put(&1, index, options))}
    else
      {:halt, socket}
    end
  end

  defp event("filter:search_contact", _, socket), do: {:halt, socket}

  defp event("filter:change", %{"filters" => params}, socket) do
    previous = rows(socket.assigns.filter_form.params)

    next =
      rows(params)
      |> Enum.with_index()
      |> Enum.map(fn {row, index} ->
        old = Enum.at(previous, index) || %{}
        normalize_row(row, old)
      end)

    {:halt, set_form(socket, next, params["name"] || "")}
  end

  defp event("filter:add", _, socket) do
    params = socket.assigns.filter_form.params
    {:halt, set_form(socket, rows(params) ++ [default_row()], params["name"] || "")}
  end

  defp event("filter:remove", %{"index" => index}, socket) do
    params = socket.assigns.filter_form.params

    case Integer.parse(index) do
      {index, ""} ->
        rows = List.delete_at(rows(params), index)

        {:halt,
         set_form(socket, if(rows == [], do: [default_row()], else: rows), params["name"] || "")}

      _ ->
        {:halt, socket}
    end
  end

  defp event("filter:clear", _, socket) do
    name = socket.assigns.filter_form.params["name"] || ""
    {:halt, socket |> assign(:filter_error, nil) |> set_form([default_row()], name)}
  end

  # ChatList.vue → resetFilters: leaves the filtered list for the unfiltered one.
  defp event("filter:reset", _, socket) do
    {:halt, socket |> assign(:filter_editor, nil) |> push_patch(to: ~p"/app")}
  end

  # Deviation from ConversationFilter.vue, which rejects an empty draft: removing the only
  # condition of an applied filter and applying is how people expect to drop it.
  # Folders still need a condition, and with nothing applied the draft is still validated.
  defp event("filter:apply", %{"filters" => params}, %{assigns: %{folder: nil}} = socket)
       when is_map(params) and socket.assigns.advanced_query != nil do
    if Enum.all?(rows(params), &blank_row?/1) do
      event("filter:reset", %{}, socket)
    else
      apply_filters(params, socket)
    end
  end

  defp event("filter:apply", %{"filters" => params}, socket), do: apply_filters(params, socket)

  defp event("filter:save_open", _, socket) do
    {:halt, socket |> assign(:filter_editor, :save) |> assign(:filter_error, nil)}
  end

  defp event("filter:save", %{"folder" => params}, socket) do
    attrs = %{name: params["name"], query: socket.assigns.advanced_query}
    socket = assign(socket, :folder_form, to_form(params, as: "folder"))

    with account when not is_nil(account) <- socket.assigns.account,
         {:ok, _} <- FilterQuery.compile(attrs.query, account),
         {:ok, folder} <-
           Accounts.create_custom_filter(socket.assigns.current_scope, account, attrs) do
      {:halt, saved(socket, folder, "Folder created successfully.")}
    else
      _ ->
        {:halt,
         assign(socket, :filter_error, "Name is required or the filter could not be saved.")}
    end
  end

  defp event("filter:delete_open", _, socket),
    do: {:halt, assign(socket, :filter_editor, :delete)}

  defp event("filter:delete", _, socket) do
    folder = socket.assigns.folder

    result =
      folder &&
        Accounts.delete_custom_filter(
          socket.assigns.current_scope,
          socket.assigns.account,
          folder.id
        )

    case result do
      {:ok, _} ->
        {:halt,
         socket
         |> refresh_folders()
         |> assign(:filter_editor, nil)
         |> put_flash(:info, "Folder deleted successfully.")
         |> push_patch(to: ~p"/app")}

      _ ->
        {:halt, put_flash(socket, :error, "Error while deleting folder.")}
    end
  end

  defp event(_, _, socket), do: {:cont, socket}

  defp allowed_values("status", _labels), do: ~w(open resolved pending snoozed)
  defp allowed_values("priority", _labels), do: ~w(low medium high urgent)
  defp allowed_values("labels", labels), do: Enum.map(labels, & &1.title)
  defp allowed_values(_, _labels), do: []

  defp normalize_row(row, old) do
    if row["attribute_key"] != old["attribute_key"] do
      operator =
        if row["attribute_key"] in ~w(created_at last_activity_at),
          do: "is_greater_than",
          else: "equal_to"

      row |> Map.put("filter_operator", operator) |> Map.put("values", "")
    else
      row
    end
  end

  defp apply_filters(params, socket) do
    query = payload(rows(params))
    socket = set_form(socket, rows(params), params["name"] || "")

    case FilterQuery.compile(query, socket.assigns.account) do
      {:ok, _} ->
        {:halt, apply_query(socket, query, params["name"])}

      {:error, _} ->
        {:halt, assign(socket, :filter_error, "Value is required or the filter is invalid.")}
    end
  end

  defp blank_row?(row) do
    row["filter_operator"] not in ~w(is_present is_not_present) &&
      String.trim(to_string(row["values"])) in ["", "[]"]
  end

  defp apply_query(%{assigns: %{folder: nil}} = socket, query, _name) do
    socket
    |> assign(:filter_editor, nil)
    |> assign(:filter_error, nil)
    |> push_patch(to: ~p"/app?#{%{"filters" => Jason.encode!(query)}}")
  end

  defp apply_query(socket, query, name) do
    case Accounts.update_custom_filter(
           socket.assigns.current_scope,
           socket.assigns.account,
           socket.assigns.folder.id,
           %{name: name, query: query}
         ) do
      {:ok, folder} -> saved(socket, folder, "Folder updated successfully.")
      _ -> assign(socket, :filter_error, "Name is required or the folder could not be updated.")
    end
  end

  defp saved(socket, folder, message) do
    socket
    |> refresh_folders()
    |> assign(:filter_editor, nil)
    |> assign(:filter_error, nil)
    |> put_flash(:info, message)
    |> push_patch(to: ~p"/app?folder_id=#{folder.id}")
  end

  defp refresh_folders(socket) do
    folders = Accounts.list_custom_filters(socket.assigns.current_scope, socket.assigns.account)
    update(socket, :sidebar, &%{&1 | folders: folders})
  end

  defp set_form(socket, rows, name) do
    params = %{
      "rows" => rows |> Enum.with_index() |> Map.new(fn {row, i} -> {to_string(i), row} end),
      "name" => name
    }

    forms =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {row, i} ->
        to_form(row, as: "filters[rows][#{i}]", id: "filter-row-#{i}")
      end)

    socket |> assign(:filter_form, to_form(params, as: "filters")) |> assign(:filter_rows, forms)
  end

  defp rows(%{"rows" => rows}) when is_map(rows) do
    rows
    |> Enum.flat_map(fn {index, row} ->
      with true <- is_binary(index) && is_map(row),
           {index, ""} when index >= 0 <- Integer.parse(index) do
        [{index, Map.take(row, ~w(attribute_key filter_operator values query_operator timezone))}]
      else
        _ -> []
      end
    end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp rows(_params), do: []

  defp payload(rows) do
    conditions =
      Enum.map(rows, fn row ->
        value = if is_binary(row["values"]), do: row["values"], else: ""

        values =
          if row["attribute_key"] in ~w(status priority labels),
            do: decode_multi(value),
            else: payload_value(value)

        Map.put(row, "values", values)
      end)

    %{"payload" => List.update_at(conditions, -1, &Map.delete(&1, "query_operator"))}
  end

  defp payload_value(value), do: if(String.trim(value) == "", do: [], else: [value])

  defp editable_row(row) do
    values = if is_list(row["values"]), do: row["values"], else: []

    value =
      values
      |> Enum.filter(&(is_binary(&1) || is_number(&1) || is_boolean(&1)))
      |> Enum.join(", ")

    value =
      if row["attribute_key"] in ~w(status priority labels),
        do: Jason.encode!(values),
        else: value

    row |> Map.put("values", value) |> Map.put("query_operator", row["query_operator"] || "and")
  end

  defp custom_value_options(%{attribute_display_type: :checkbox}), do: ~w(true false)

  defp custom_value_options(%{attribute_display_type: :list, attribute_values: values})
       when is_list(values),
       do: Enum.filter(values, &is_binary/1)

  defp custom_value_options(_), do: []

  defp parse_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {number, ""} when number >= 0 -> number
      _ -> nil
    end
  end

  defp parse_index(_), do: nil

  defp selected_contacts(nil, _rows), do: %{}

  defp selected_contacts(account, rows) do
    rows
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {row, index}, acc ->
      with "contact_id" <- row["attribute_key"],
           {id, ""} <- Integer.parse(row["values"] || ""),
           contact when not is_nil(contact) <- Contacts.get_contact(account, id) do
        Map.put(acc, index, [contact_option(contact)])
      else
        _ -> acc
      end
    end)
  end

  defp contact_option(contact) do
    label =
      Enum.find(
        [
          contact.name,
          contact.email,
          contact.phone_number,
          contact.identifier,
          to_string(contact.id)
        ],
        &(is_binary(&1) && &1 != "")
      )

    {to_string(contact.id), label}
  end

  defp value_options(nil), do: %{"browser_language" => @languages}

  defp value_options(account) do
    %{
      "assignee_id" =>
        Accounts.list_account_users(account)
        |> Enum.map(fn membership ->
          user = membership.user

          {to_string(user.id),
           Enum.find([user.name, user.email, to_string(user.id)], &(is_binary(&1) && &1 != ""))}
        end),
      "inbox_id" => Enum.map(Inboxes.list_inboxes(account), &{to_string(&1.id), &1.name}),
      "team_id" => Enum.map(Accounts.list_teams(account), &{to_string(&1.id), &1.name}),
      "campaign_id" =>
        Enum.map(Automations.list_campaigns(account), &{to_string(&1.id), &1.title}),
      "browser_language" => @languages
    }
  end

  defp decode_multi(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, values} when is_list(values) -> Enum.filter(values, &is_binary/1)
      _ -> String.split(value, ",", trim: true) |> Enum.map(&String.trim/1)
    end
  end

  defp decode_multi(_), do: []

  defp default_row,
    do: %{
      "attribute_key" => "status",
      "filter_operator" => "equal_to",
      "values" => "",
      "query_operator" => "and"
    }
end
