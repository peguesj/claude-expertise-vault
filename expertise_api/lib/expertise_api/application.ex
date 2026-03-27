defmodule ExpertiseApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExpertiseApiWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:expertise_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ExpertiseApi.PubSub},
      # Authority syncer — periodic background fetch from tracked expert sources
      ExpertiseApi.AuthoritySyncer,
      # Start to serve requests, typically the last entry
      ExpertiseApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExpertiseApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExpertiseApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
