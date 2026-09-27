defmodule ChatwooterWeb.LiveRoutesTest do
  @moduledoc """
  Garante a convenção "rota = arquivo" dos LiveViews (ver AGENTS.md → Frontend):

      /app/<a>            → live/<a>/index.ex        → ChatwooterWeb.<A>Live.Index
      /app/<a>/:param     → live/<a>/show.ex         → ChatwooterWeb.<A>Live.Show
      /app/<a>/<b>        → live/<a>/<b>.ex          → ChatwooterWeb.<A>Live.<B>
      /app/<a>/<b>/:param → live/<a>/<b>/show.ex     → ChatwooterWeb.<A>Live.<B>.Show

  `/app` é a caixa de conversas (como no Chatwoot) → `live/conversations/index.ex`.
  """
  use ExUnit.Case, async: true

  @live_dir Path.expand("../../lib/chatwooter_web/live", __DIR__)

  defp live_routes do
    for %{
          path: "/app" <> _ = path,
          plug: Phoenix.LiveView.Plug,
          metadata: %{phoenix_live_view: {module, _, _, _}}
        } <-
          ChatwooterWeb.Router.__routes__(),
        do: {path, module}
  end

  defp expected(path) do
    case path |> String.trim_leading("/app") |> String.split("/", trim: true) do
      [] -> expected_for(["conversations"])
      segments -> expected_for(segments)
    end
  end

  defp expected_for([first | rest]) do
    parts = Enum.map(rest, &part/1)

    {files, last} =
      case parts do
        [] -> {[], "index"}
        _ -> {Enum.drop(parts, -1), List.last(parts)}
      end

    module =
      Module.concat(
        [ChatwooterWeb, Macro.camelize(snake(first)) <> "Live"] ++
          Enum.map(files ++ [last], &Macro.camelize/1)
      )

    {Path.join([@live_dir, snake(first) | files] ++ [last <> ".ex"]), module}
  end

  defp part(":" <> _param), do: "show"
  defp part(segment), do: snake(segment)

  defp snake(segment), do: String.replace(segment, "-", "_")

  test "todo LiveView de /app segue a convenção rota = arquivo" do
    routes = live_routes()
    assert routes != []

    for {path, module} <- routes do
      {file, expected_module} = expected(path)

      assert module == expected_module,
             "#{path} deveria usar #{inspect(expected_module)}, usa #{inspect(module)}"

      assert File.exists?(file), "#{path} deveria estar em #{Path.relative_to_cwd(file)}"

      assert module.__info__(:compile)[:source] |> to_string() == file,
             "#{inspect(module)} deveria estar definido em #{Path.relative_to_cwd(file)}"
    end
  end

  test "cada página tem o markup num .html.heex ao lado" do
    for {_path, module} <- live_routes(), module.__info__(:functions)[:render] == 1 do
      source = to_string(module.__info__(:compile)[:source])
      template = String.replace_suffix(source, ".ex", ".html.heex")

      assert File.exists?(template) or redirect_only?(source),
             "#{Path.relative_to_cwd(source)} precisa de #{Path.basename(template)}"
    end
  end

  # páginas que só aplicam um token e redirecionam não têm markup
  defp redirect_only?(source), do: source |> File.read!() |> String.contains?("# só redireciona")
end
