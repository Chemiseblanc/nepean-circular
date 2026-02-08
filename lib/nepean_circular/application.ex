defmodule NepeanCircular.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NepeanCircularWeb.Telemetry,
      NepeanCircular.Repo,
      {Oban,
       AshOban.config(
         Application.fetch_env!(:nepean_circular, :ash_domains),
         Application.fetch_env!(:nepean_circular, Oban)
       )},
      {Ecto.Migrator,
       repos: Application.fetch_env!(:nepean_circular, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:nepean_circular, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NepeanCircular.PubSub},
      # Start to serve requests, typically the last entry
      NepeanCircularWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NepeanCircular.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NepeanCircularWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
