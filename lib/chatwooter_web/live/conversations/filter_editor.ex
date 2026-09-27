defmodule ChatwooterWeb.ConversationsLive.FilterEditor do
  @moduledoc "State for ConversationFilter.vue, SaveCustomView.vue and DeleteCustomViews.vue."
  use ChatwooterWeb, :verified_routes
  import Phoenix.Component
  import Phoenix.LiveView
  alias Chatwooter.Accounts
  alias Chatwooter.Conversations.FilterQuery

  def mount(socket) do
    socket
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
           {:ok, _} <- FilterQuery.compile(query) do
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
     socket |> assign(:filter_editor, :edit) |> assign(:filter_error, nil) |> set_form(rows, name)}
  end

  defp event("filter:close", _, socket), do: {:halt, assign(socket, :filter_editor, nil)}

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

  defp event("filter:apply", %{"filters" => params}, socket) do
    query = payload(rows(params))
    socket = set_form(socket, rows(params), params["name"] || "")

    case FilterQuery.compile(query) do
      {:ok, _} ->
        {:halt, apply_query(socket, query, params["name"])}

      {:error, _} ->
        {:halt, assign(socket, :filter_error, "Value is required or the filter is invalid.")}
    end
  end

  defp event("filter:save_open", _, socket) do
    {:halt, socket |> assign(:filter_editor, :save) |> assign(:filter_error, nil)}
  end

  defp event("filter:save", %{"folder" => params}, socket) do
    attrs = %{name: params["name"], query: socket.assigns.advanced_query}
    socket = assign(socket, :folder_form, to_form(params, as: "folder"))

    with account when not is_nil(account) <- socket.assigns.account,
         {:ok, _} <- FilterQuery.compile(attrs.query),
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
        Map.put(row, "values", String.split(value, ",", trim: true) |> Enum.map(&String.trim/1))
      end)

    %{"payload" => List.update_at(conditions, -1, &Map.delete(&1, "query_operator"))}
  end

  defp editable_row(row) do
    values = if is_list(row["values"]), do: row["values"], else: []
    value = values |> Enum.filter(&(is_binary(&1) || is_number(&1))) |> Enum.join(", ")
    row |> Map.put("values", value) |> Map.put("query_operator", row["query_operator"] || "and")
  end

  defp default_row,
    do: %{
      "attribute_key" => "status",
      "filter_operator" => "equal_to",
      "values" => "",
      "query_operator" => "and"
    }
end
