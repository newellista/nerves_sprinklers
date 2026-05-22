defmodule NervesSprinklers.Application do
  @moduledoc false

  use Application

  alias NervesSprinklers.Config.NodeConfig

  @impl true
  def start(_type, _args) do
    children =
      [
        {Cluster.Supervisor,
         [
           Application.get_env(:libcluster, :topologies, []),
           [name: NervesSprinklers.ClusterSupervisor]
         ]},
        NervesSprinklers.Gpio.GpioServer
      ] ++ coordinator_children()

    opts = [strategy: :one_for_one, name: NervesSprinklers.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp coordinator_children do
    if NodeConfig.coordinator?() do
      [NervesSprinklers.Repo] ++
        migrator_children() ++
        [NervesSprinklersWeb.Endpoint]
    else
      []
    end
  end

  defp migrator_children do
    repo_config = Application.get_env(:nerves_sprinklers, NervesSprinklers.Repo, [])

    if repo_config[:pool] == Ecto.Adapters.SQL.Sandbox do
      []
    else
      [{Ecto.Migrator, repos: Application.fetch_env!(:ecto, :repos), log_migrations_sql: false}]
    end
  end
end
