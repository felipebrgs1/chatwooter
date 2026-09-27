defmodule ChatwooterWeb.TimeAgo do
  @moduledoc """
  Tempo relativo como no Chatwoot (`shared/helpers/timeHelper.js`):

    * `long/2`  — `dynamicTime`: `formatDistanceToNow(…, addSuffix: true)` do date-fns
      ("less than a minute ago", "about 5 hours ago", "3 days ago"...)
    * `short/2` — `shortTimestamp(dynamicTime(…))` ("now", "5h", "3d", "1mo", "1y")
  """

  @minutes_in_day 1440
  @minutes_in_month 43_200

  def long(datetime, now \\ DateTime.utc_now())
  def long(nil, _now), do: ""
  def long(datetime, now), do: distance(to_utc(datetime), now) <> " ago"

  def short(datetime, now \\ DateTime.utc_now())
  def short(nil, _now), do: ""

  def short(datetime, now) do
    case long(datetime, now) do
      "less than a minute ago" ->
        "now"

      text ->
        text
        |> String.replace(~r/about|over|almost/, "")
        |> String.replace(~r/ (minute|hour|day|month|year)s? ago$/, fn match ->
          match |> String.trim() |> String.split() |> hd() |> unit_suffix()
        end)
        |> String.trim()
    end
  end

  defp unit_suffix("minute" <> _), do: "m"
  defp unit_suffix("hour" <> _), do: "h"
  defp unit_suffix("day" <> _), do: "d"
  defp unit_suffix("month" <> _), do: "mo"
  defp unit_suffix("year" <> _), do: "y"

  # date-fns formatDistance (en-US), sem includeSeconds
  defp distance(datetime, now) do
    minutes = round(DateTime.diff(now, datetime) / 60)

    if minutes < @minutes_in_day,
      do: distance_within_day(minutes),
      else: distance_beyond_day(datetime, now, minutes)
  end

  defp distance_within_day(minutes) do
    cond do
      minutes < 1 -> "less than a minute"
      minutes < 2 -> "1 minute"
      minutes < 45 -> "#{minutes} minutes"
      minutes < 90 -> "about 1 hour"
      true -> "about #{round(minutes / 60)} hours"
    end
  end

  defp distance_beyond_day(datetime, now, minutes) do
    cond do
      minutes < 2520 ->
        "1 day"

      minutes < @minutes_in_month ->
        "#{round(minutes / @minutes_in_day)} days"

      minutes < 2 * @minutes_in_month ->
        "about #{plural(round(minutes / @minutes_in_month), "month")}"

      true ->
        months_or_years(datetime, now, minutes)
    end
  end

  defp months_or_years(datetime, now, minutes) do
    months = calendar_months(datetime, now)

    if months < 12 do
      plural(round(minutes / @minutes_in_month), "month")
    else
      years = div(months, 12)

      case rem(months, 12) do
        rest when rest < 3 -> "about #{plural(years, "year")}"
        rest when rest < 9 -> "over #{plural(years, "year")}"
        _rest -> "almost #{plural(years + 1, "year")}"
      end
    end
  end

  defp plural(1, unit), do: "1 #{unit}"
  defp plural(n, unit), do: "#{n} #{unit}s"

  defp calendar_months(from, to) do
    months = (to.year - from.year) * 12 + (to.month - from.month)
    if to_day_time(to) < to_day_time(from), do: months - 1, else: months
  end

  defp to_day_time(dt), do: {dt.day, dt.hour, dt.minute, dt.second}

  defp to_utc(%DateTime{} = dt), do: dt
  defp to_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")

  @doc "Data/hora exata do tooltip (useExactTimestamp)."
  def exact(nil), do: ""
  def exact(datetime), do: Calendar.strftime(datetime, "%b %-d %Y, %-I:%M %p")
end
