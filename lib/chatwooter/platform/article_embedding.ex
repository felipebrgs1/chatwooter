defmodule Chatwooter.Platform.ArticleEmbedding do
  @moduledoc "Read mapping of upstream article_embeddings; embeddings are preserved opaquely."
  use Ecto.Schema

  schema "article_embeddings" do
    field :article_id, :integer
    field :term, :string
    field :embedding, Pgvector.Ecto.Vector
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
