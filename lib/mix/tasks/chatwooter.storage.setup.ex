defmodule Mix.Tasks.Chatwooter.Storage.Setup do
  @moduledoc """
  Cria o bucket de anexos no object storage e libera leitura pública.

  Uso: `mix chatwooter.storage.setup` (com `STORAGE_*`/`RUSTFS_*` no ambiente).
  """
  use Mix.Task

  @shortdoc "Cria o bucket de anexos (RustFS/S3)"

  @impl Mix.Task
  def run(_args) do
    # Tasks não carregam `config/runtime.exs` sozinhas: sobe o app
    # (sem HTTP) para que o S3 aponte p/ o endpoint configurado.
    Application.put_env(:chatwooter, ChatwooterWeb.Endpoint, server: false)
    Mix.Task.run("app.start")

    bucket = bucket()

    Mix.shell().info("bucket: #{bucket}")

    with {:ok, %{status_code: status}} when status in 200..299 <-
           ExAws.S3.put_bucket(bucket, region()) |> ExAws.request(),
         {:ok, %{status_code: policy_status}} when policy_status in 200..299 <-
           ExAws.S3.put_bucket_policy(bucket, public_read_policy(bucket)) |> ExAws.request() do
      Mix.shell().info("ok: bucket pronto com leitura pública")
    else
      {:ok, %{status_code: status, body: body}} ->
        Mix.raise("storage setup falhou (HTTP #{status}): #{inspect(body)}")

      {:error, reason} ->
        Mix.raise("storage setup falhou: #{inspect(reason)}")
    end
  end

  defp bucket, do: Application.get_env(:chatwooter, :storage, [])[:bucket] || "chatwooter-dev"
  defp region, do: Application.get_env(:ex_aws, :s3, [])[:region] || "us-east-1"

  defp public_read_policy(bucket) do
    Jason.encode!(%{
      "Version" => "2012-10-17",
      "Statement" => [
        %{
          "Effect" => "Allow",
          "Principal" => %{"AWS" => "*"},
          "Action" => ["s3:GetObject"],
          "Resource" => ["arn:aws:s3:::#{bucket}/*"]
        }
      ]
    })
  end
end
