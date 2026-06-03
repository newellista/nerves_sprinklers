defmodule NervesSprinklers.Cluster.NodeWatcher do
  @moduledoc false

  use GenServer

  alias NervesSprinklers.Executor.Executor

  @pubsub NervesSprinklers.PubSub
  @topic "cluster:nodes"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def connected_nodes do
    GenServer.call(__MODULE__, :connected_nodes)
  end

  @impl true
  def init(_opts) do
    :net_kernel.monitor_nodes(true, node_type: :all)
    workers = Node.list() |> MapSet.new()
    {:ok, %{workers: workers}}
  end

  @impl true
  def handle_call(:connected_nodes, _from, state) do
    {:reply, MapSet.to_list(state.workers) ++ [node()], state}
  end

  @impl true
  def handle_info({:nodeup, node, _info}, state) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:node_up, node})
    {:noreply, %{state | workers: MapSet.put(state.workers, node)}}
  end

  def handle_info({:nodedown, node, _info}, state) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:node_down, node})
    Executor.node_went_down(node)
    {:noreply, %{state | workers: MapSet.delete(state.workers, node)}}
  end
end
