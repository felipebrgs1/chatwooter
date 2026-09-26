defmodule Chatwooter.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ChatwooterWeb.Telemetry,
      Chatwooter.Repo,
      {DNSCluster, query: Application.get_env(:chatwooter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Chatwooter.PubSub},
      # Start a worker by calling: Chatwooter.Worker.start_link(arg)
      # {Chatwooter.Worker, arg},
      # Start to serve requests, typically the last entry
      ChatwooterWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chatwooter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChatwooterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
