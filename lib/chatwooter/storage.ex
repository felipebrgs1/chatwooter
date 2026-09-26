defmodule Chatwooter.Storage do
  @moduledoc """
  Upload de anexos p/ object storage S3-compatível (RustFS).

  Dois endereços: `endpoint` (upload, alcançável pelo servidor) e
  `public_url` (leitura, alcançável pelo browser) — ver `config/runtime.exs`.
  """

  @doc "Faz upload dos bytes e retorna chave + URL pública."
  def put_object(key, bytes, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    operation =
      ExAws.S3.put_object(bucket(), key, bytes, content_type: content_type)

    case ExAws.request(operation) do
      {:ok, %{status_code: status}} when status in 200..299 ->
        {:ok,
         %{
           key: key,
           url: public_url(key),
           content_type: content_type,
           size_bytes: byte_size(bytes)
         }}

      {:error, {:http_error, status, body}} ->
        {:error, %{code: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "URL pública (browser) de uma chave."
  def public_url(key), do: "#{public_base()}/#{bucket()}/#{key}"

  defp bucket, do: storage_config()[:bucket] || "chatwooter-dev"

  defp public_base, do: storage_config()[:public_url] || "http://localhost:9000"

  defp storage_config, do: Application.get_env(:chatwooter, :storage, [])
end
