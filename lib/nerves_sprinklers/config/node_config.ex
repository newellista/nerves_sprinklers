defmodule NervesSprinklers.Config.NodeConfig do
  @moduledoc false

  def role, do: Application.fetch_env!(:nerves_sprinklers, :role)

  def coordinator?, do: role() == :coordinator

  def worker?, do: role() == :worker

  def node_name, do: Application.fetch_env!(:nerves_sprinklers, :node_name)

  def timezone, do: Application.fetch_env!(:nerves_sprinklers, :timezone)
end
