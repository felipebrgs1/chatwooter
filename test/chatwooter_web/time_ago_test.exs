defmodule ChatwooterWeb.TimeAgoTest do
  use ExUnit.Case, async: true

  alias ChatwooterWeb.TimeAgo

  @now ~U[2026-09-27 12:00:00Z]

  defp ago(seconds), do: TimeAgo.short(DateTime.add(@now, -seconds), @now)

  test "matches date-fns distance + Chatwoot shortTimestamp buckets" do
    assert ago(10) == "now"
    assert ago(60) == "1m"
    assert ago(44 * 60) == "44m"
    assert ago(50 * 60) == "1h"
    assert ago(5 * 3600) == "5h"
    assert ago(30 * 3600) == "1d"
    assert ago(3 * 86_400) == "3d"
    assert ago(35 * 86_400) == "1mo"
    assert ago(50 * 86_400) == "2mo"
    assert ago(200 * 86_400) == "7mo"
    assert TimeAgo.short(~U[2025-08-27 12:00:00Z], @now) == "1y"
    assert TimeAgo.short(~U[2024-10-27 12:00:00Z], @now) == "2y"
  end

  test "long form matches date-fns formatDistanceToNow with suffix" do
    long = &TimeAgo.long(DateTime.add(@now, -&1), @now)

    assert long.(10) == "less than a minute ago"
    assert long.(60) == "1 minute ago"
    assert long.(5 * 3600) == "about 5 hours ago"
    assert long.(3 * 86_400) == "3 days ago"
    assert TimeAgo.long(~U[2025-08-27 12:00:00Z], @now) == "about 1 year ago"
    assert TimeAgo.long(~U[2025-02-27 12:00:00Z], @now) == "over 1 year ago"
  end

  test "handles nil and naive datetimes" do
    assert TimeAgo.short(nil, @now) == ""
    assert TimeAgo.short(~N[2026-09-27 11:00:00], @now) == "1h"
  end
end
