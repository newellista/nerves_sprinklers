defmodule NervesSprinklers.Executor.ZoneDriver do
  @moduledoc false

  alias NervesSprinklers.Gpio.GpioServer
  alias NervesSprinklers.Schema.Zone
  require Logger

  @remote_timeout 5_000

  def activate(zone) do
    call_gpio(zone, {:open_pin, zone.gpio_pin})
  end

  def deactivate(zone) do
    call_gpio(zone, {:close_pin, zone.gpio_pin})
  end

  defp call_gpio(zone, msg) do
    target_node = Zone.node_atom(zone)

    if target_node == node() do
      GenServer.call(GpioServer, msg)
    else
      GenServer.call({GpioServer, target_node}, msg, @remote_timeout)
    end
  catch
    :exit, reason ->
      Logger.error("ZoneDriver: failed to reach GpioServer on #{zone.node}: #{inspect(reason)}")
      {:error, :unreachable}
  end
end
