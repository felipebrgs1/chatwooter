defmodule Chatwooter.Conversations.DateFilter do
  @moduledoc "Date boundaries from Chatwoot app/services/filters/date_filter_helper.rb."
  import Ecto.Query
  alias Chatwooter.Repo

  @fields %{"created_at" => :inserted_at, "last_activity_at" => :last_activity_at}

  def compile(%{"attribute_key" => key, "filter_operator" => operator, "values" => [value]} = row)
      when operator in ~w(is_greater_than is_less_than days_before) do
    with {:ok, zone} <- timezone(row),
         {:ok, boundary} <- boundary(value, operator, zone) do
      predicate(Map.fetch!(@fields, key), operator, boundary, zone)
    end
  end

  def compile(_row), do: {:error, :invalid_date_filter}

  defp timezone(row) do
    if Map.has_key?(row, "timezone") do
      zone = row["timezone"]
      if is_binary(zone) && valid_zone?(zone), do: {:ok, zone}, else: {:error, :invalid_timezone}
    else
      {:ok, nil}
    end
  end

  # PostgreSQL's IANA catalog supplies DST rules without adding a second timezone database.
  defp valid_zone?(zone) do
    %{rows: [[valid]]} =
      Repo.query!("SELECT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name = $1)", [zone])

    valid
  end

  defp boundary(value, "days_before", zone) do
    case Ecto.Type.cast(:integer, value) do
      {:ok, days} when days in 1..998 ->
        %{rows: [[today]]} =
          Repo.query!("SELECT (CURRENT_TIMESTAMP AT TIME ZONE $1)::date", [zone || "UTC"])

        {:ok, Date.add(today, -days)}

      _ ->
        {:error, :invalid_days}
    end
  end

  defp boundary(value, _operator, _zone) when is_binary(value), do: Date.from_iso8601(value)
  defp boundary(_value, _operator, _zone), do: {:error, :invalid_date}

  defp predicate(field, "is_greater_than", date, nil),
    do: {:ok, dynamic([c], fragment("?::date", field(c, ^field)) > ^date)}

  defp predicate(field, _operator, date, nil),
    do: {:ok, dynamic([c], fragment("?::date", field(c, ^field)) < ^date)}

  defp predicate(field, "is_greater_than", date, zone) do
    next_day = Date.add(date, 1)

    {:ok,
     dynamic(
       [c],
       field(c, ^field) >=
         fragment(
           "(?::date::timestamp AT TIME ZONE ? AT TIME ZONE 'UTC')",
           type(^next_day, :date),
           ^zone
         )
     )}
  end

  defp predicate(field, _operator, date, zone) do
    {:ok,
     dynamic(
       [c],
       field(c, ^field) <
         fragment(
           "(?::date::timestamp AT TIME ZONE ? AT TIME ZONE 'UTC')",
           type(^date, :date),
           ^zone
         )
     )}
  end
end
