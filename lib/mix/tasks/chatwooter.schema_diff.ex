defmodule Mix.Tasks.Chatwooter.SchemaDiff do
  use Mix.Task

  @shortdoc "Compara o PostgreSQL migrado ao snapshot do Chatwoot"
  @moduledoc """
  Compare the migrated database to the pinned Rails schema (read-only):

      mix chatwooter.schema_diff
      mix chatwooter.schema_diff --json docs/schema_parity_baseline.json

  Requires a running, migrated PostgreSQL database. JSON contains every observed
  column, index, foreign key, check, extension and trigger, including differences.
  This is a diagnostic command; differences do not cause a non-zero exit status.
  """

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: [json: :string])

    if rest != [] or invalid != [],
      do: Mix.raise("usage: mix chatwooter.schema_diff [--json PATH]")

    Mix.Task.run("app.start")
    path = Path.expand("chatwoot/db/schema.rb", File.cwd!())
    report = Chatwooter.SchemaParity.compare(Chatwooter.Repo, path)

    fingerprint =
      path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    report = Map.put(report, :snapshot_sha256, fingerprint)

    Mix.shell().info("Chatwoot #{report.version} (SHA256 #{fingerprint})")

    Mix.shell().info(
      "Tabelas: #{report.summary.compared_tables}/#{report.summary.upstream_tables} presentes; #{report.summary.missing_tables} ausentes. Paridade literal: #{report.summary.parity?}"
    )

    Mix.shell().info("Ausentes: #{Enum.join(report.missing_tables, ", ")}")

    if output = opts[:json] do
      File.mkdir_p!(Path.dirname(output))
      File.write!(output, Jason.encode!(report, pretty: true) <> "\n")
      Mix.shell().info("Relatório: #{output}")
    end
  end
end
