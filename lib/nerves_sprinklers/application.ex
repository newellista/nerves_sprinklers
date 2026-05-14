defmodule NervesSprinklers.Application do
  @moduledoc false

  use Application

  alias NervesSprinklers.Config.NodeConfig

  @impl true
  def start(_type, _args) do
    children =
      [
        {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies, []), [name: NervesSprinklers.ClusterSupervisor]]},
        NervesSprinklers.Gpio.GpioServer
      ] ++ coordinator_children()

    opts = [strategy: :one_for_one, name: NervesSprinklers.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp coordinator_children do
    if NodeConfig.coordinator?() do
      [
        NervesSprinklers.Repo,
        NervesSprinklersWeb.Endpoint
      ]
    else
      []
    end
  end
end
